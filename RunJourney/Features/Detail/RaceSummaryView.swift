import SwiftUI
import SwiftData

/// 地図上のピンをタップしたときに開く、Race の「閲覧用」モーダル。
///
/// 旧 `RaceDetailView` を直接シートに入れていた頃は、Race Info セクションの編集
/// フィールド (TextField "Race Name") に加えて navigationTitle、ヘッダー行の名前と
/// 同じ大会名が 3 か所に並び、画面が渋滞していた。さらに編集 UI と閲覧 UI を兼ねる
/// ため、ぱっと見の要約性に欠けていた。
///
/// この View では:
/// - 上半分に「要約」(ロゴ・名前・カテゴリ・距離・場所・サイトへのリンク) を 1 ブロック
///   に集約し、編集はツールバーの鉛筆アイコンから別シート (= `RaceDetailView`) に分離。
/// - 下半分に Results 一覧をそのまま並べ、シートを上にドラッグしただけで Results が
///   主役になるようにする (= `presentationDetents([.medium, .large])` 前提)。
struct RaceSummaryView: View {
    @Bindable var race: Race
    @Environment(\.modelContext) private var modelContext

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    @State private var showEditSheet = false
    @State private var showAddResultSheet = false

    private var sortedResults: [RaceResult] {
        (race.results ?? []).sorted { $0.raceDate > $1.raceDate }
    }

    private var pbSeconds: Double? {
        sortedResults
            .compactMap { ($0.isDNF || $0.isDNS) ? nil : $0.finishTimeSec }
            .min()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                resultsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(race.category.displayName)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }
                .accessibilityLabel("Edit Race")
            }
        }
#endif
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                RaceDetailView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                try? modelContext.save()
                                showEditSheet = false
                            }
                            .appText(.bodyBaseBold)
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddResultSheet) {
            AddResultSheet(race: race)
        }
    }

    // MARK: - Summary card
    //
    // 「要約」ブロック。ロゴ + 名前 + カテゴリ icon を 1 行、その下にメタ情報 (距離 / 場所 /
    // サイト) を最小限。編集は鉛筆アイコンに分離しているので、ここは TextField を一切
    // 出さない (= 同じ情報が複数の入力欄として並ぶ渋滞を防ぐ)。

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                logoBox
                VStack(alignment: .leading, spacing: 6) {
                    Text(race.name.isEmpty ? "Untitled Race" : race.name)
                        .appText(.bodyMdBold)
                        .foregroundStyle(race.name.isEmpty ? .tertiary : Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Image(systemName: race.category.symbolName)
                            .font(.caption)
                            .foregroundStyle(Color.accentPrimary)
                        Text(race.category.displayName)
                            .appText(.bodyXs)
                            .foregroundStyle(.secondary)
                        if let distanceText {
                            Text("·")
                                .appText(.bodyXs)
                                .foregroundStyle(.tertiary)
                            Text(distanceText)
                                .appText(.codeXs)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            if let location = locationText {
                metaRow(systemImage: "mappin.and.ellipse", text: location)
            }

            if let url = validWebsiteURL {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                            .font(.caption)
                            .foregroundStyle(Color.accentPrimary)
                        Text(url.host ?? url.absoluteString)
                            .appText(.bodyXs)
                            .foregroundStyle(Color.accentPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func metaRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .appText(.bodyXs)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var logoBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgSecondary)
            if let url = RaceLogoStore.url(for: race.logoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.small)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    case .failure:
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.tertiary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results
    //
    // ScrollView 配下に並ぶシンプルなリスト。シートを上に引っ張ったときに自然と
    // Results が前面に来るよう、間に VStack のみで仕切る (Form を使うと内部 ScrollView
    // が二重になり、シートのドラッグ展開が効きにくくなる)。

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Results", subtitle: "\(sortedResults.count)") {
                Button {
                    showAddResultSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Result")
            }

            if sortedResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No results yet")
                        .appText(.bodyBase)
                        .foregroundStyle(.secondary)
                    Text("Tap + to add a result manually, or import a TCX / GPX / FIT / ZIP file.")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedResults.enumerated()), id: \.element.id) { index, result in
                        NavigationLink {
                            RaceResultDetailView(result: result)
                        } label: {
                            HStack(spacing: 8) {
                                RaceResultRow(result: result, isPB: result.finishTimeSec == pbSeconds && pbSeconds != nil)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < sortedResults.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Derived

    private var distanceText: String? {
        guard let km = race.distanceKm, km > 0 else { return nil }
        return PaceUtils.formatDistance(km: km, in: unit)
    }

    private var locationText: String? {
        let parts = [race.city, race.country].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        if let addr = race.address?.trimmingCharacters(in: .whitespaces), !addr.isEmpty {
            return addr
        }
        return nil
    }

    private var validWebsiteURL: URL? {
        guard let raw = race.websiteURL?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}
