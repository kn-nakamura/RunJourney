import SwiftUI
import StoreKit

/// `sheet(item:)` の Identifiable 要件を満たすために `String` をラップしただけの値型。
/// 「現在の reason 文字列」をそのまま `id` として使うので、内容が変わると別シートとして扱われる。
struct PaywallReason: Identifiable {
    let text: String
    var id: String { text }

    init(_ text: String) {
        self.text = text
    }
}

/// Premium + Tip Jar の購入動線を集約したシート。
///
/// 表示文脈 (`reason`) を渡すと、シート上部に「なぜここに来たか」を 1 行表示する：
/// - "Add an unlimited number of races." (= Race 上限ヒット)
/// - "Attach PDFs and photos."           (= 添付バイナリ追加)
/// - nil の場合は汎用の Premium 案内
struct PaywallSheet: View {
    let reason: String?

    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    @State private var purchaseInFlight: PurchaseManager.ProductID?
    @State private var errorMessage: String?
    @State private var showThankYou = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let reason {
                        contextBanner(reason: reason)
                    }
                    premiumHero
                    tipJar
                }
                .padding(20)
            }
            .background(Color.bgPrimary)
            .navigationTitle("RunJourney Premium")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await restore() }
                    } label: {
                        Text("Restore")
                            .appText(.bodySm)
                    }
                }
            }
            .task {
                if purchases.products.isEmpty {
                    await purchases.loadProducts()
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
            .alert("Thank you!", isPresented: $showThankYou) {
                Button("OK") { showThankYou = false }
            } message: {
                Text("Your support means a lot. Keep on running.")
            }
        }
    }

    // MARK: - Sections

    private func contextBanner(reason: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Premium Feature")
                    .appText(.eyebrow)
                    .foregroundStyle(.secondary)
                Text(reason)
                    .appText(.bodySm)
                    .foregroundStyle(Color.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var premiumHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PREMIUM")
                    .appText(.eyebrow)
                    .foregroundStyle(Color.accentPrimary)
                Text("Unlock the full RunJourney")
                    .appText(.displayMd)
                    .foregroundStyle(Color.textPrimary)
            }

            VStack(alignment: .leading, spacing: 10) {
                benefitRow(symbol: "infinity", title: "Unlimited races and results",
                           detail: "Free is limited to \(PremiumLimits.freeRaceLimit) races and \(PremiumLimits.freeResultLimit) total results.")
                benefitRow(symbol: "doc.richtext", title: "Attach PDFs and photos",
                           detail: "Save brochures, route maps, and event-day shots — synced via iCloud.")
                benefitRow(symbol: "flag.checkered", title: "Custom race logos",
                           detail: "Use your own image as the race logo, not just a URL.")
            }

            premiumCTA
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.accentPrimary.opacity(0.35), lineWidth: 1)
        )
    }

    private func benefitRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appText(.bodyMdBold)
                    .foregroundStyle(Color.textPrimary)
                Text(detail)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var premiumCTA: some View {
        if purchases.hasPremium {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentPrimary)
                Text("Premium Active")
                    .appText(.bodyMdBold)
                    .foregroundStyle(Color.accentPrimary)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.accentPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        } else if let product = purchases.product(for: .premium) {
            Button {
                Task { await purchase(.premium) }
            } label: {
                HStack {
                    if purchaseInFlight == .premium {
                        ProgressView().controlSize(.small).tint(.black)
                    } else {
                        Text("Upgrade — \(product.displayPrice)")
                            .appText(.bodyMdBold)
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentPrimary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(purchaseInFlight != nil)
        } else {
            HStack {
                ProgressView().controlSize(.small)
                Text("Loading price...")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Tip Jar

    @ViewBuilder
    private var tipJar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TIP JAR")
                    .appText(.eyebrow)
                    .foregroundStyle(.secondary)
                Text("Optional support — no extra features")
                    .appText(.bodySm)
                    .foregroundStyle(Color.textPrimary)
            }
            VStack(spacing: 10) {
                tipButton(.tipSmall, label: "Small Tip")
                tipButton(.tipMedium, label: "Medium Tip")
                tipButton(.tipLarge, label: "Large Tip")
            }
            if purchases.tipCount > 0 {
                Text("Thank you — supported \(purchases.tipCount) time\(purchases.tipCount == 1 ? "" : "s") so far.")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18))
    }

    private func tipButton(_ id: PurchaseManager.ProductID, label: String) -> some View {
        let product = purchases.product(for: id)
        let inFlight = purchaseInFlight == id
        return Button {
            Task { await purchase(id) }
        } label: {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.accentPrimary)
                Text(label)
                    .appText(.bodyMd)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if inFlight {
                    ProgressView().controlSize(.small)
                } else if let product {
                    Text(product.displayPrice)
                        .appText(.codeBaseBold)
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Text("—")
                        .appText(.codeBase)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(product == nil || purchaseInFlight != nil)
    }

    // MARK: - Actions

    private func purchase(_ id: PurchaseManager.ProductID) async {
        purchaseInFlight = id
        defer { purchaseInFlight = nil }
        do {
            let bought = try await purchases.purchase(id)
            if bought, id.isTip {
                showThankYou = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            try await purchases.restore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
