import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// 大会(Race)のロゴ画像を PhotosPicker / クリップボードから選び、`Race.logoData` に格納する。
/// CloudKit 同期 ON ならそのまま CKAsset として他端末へ転送される。
struct LogoPicker: View {
    @Bindable var race: Race
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var paywallReason: String? = nil

    @Environment(PurchaseManager.self) private var purchases

    private var imageGated: Bool {
        PremiumLimits.logoImageRequiresPremium && !purchases.hasPremium
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                logoPreview
                VStack(alignment: .leading, spacing: 6) {
                    if imageGated {
                        Button {
                            paywallReason = "Use a custom logo image for races. URL logos are available on the free plan."
                        } label: {
                            Label("Choose Logo (Premium)", systemImage: "lock.fill")
                                .appText(.bodySmBold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.bgTertiary)
                        .foregroundStyle(Color.textPrimary)
                    } else {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(
                                hasLogo ? "Replace Logo" : "Choose Logo",
                                systemImage: "photo.on.rectangle"
                            )
                            .appText(.bodySmBold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.bgTertiary)
                        .foregroundStyle(Color.textPrimary)

                        Button {
                            pasteImageFromClipboard()
                        } label: {
                            Label("Paste Logo", systemImage: "doc.on.clipboard")
                                .appText(.bodySmBold)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.bgTertiary)
                        .foregroundStyle(Color.textPrimary)
                    }

                    if hasLogo {
                        Button(role: .destructive) {
                            RaceLogoStore.deleteLocalArtifacts(for: race)
                            race.logoURL = nil
                            race.logoData = nil
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .appText(.bodyXs)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                Spacer(minLength: 0)
            }
            if let errorMessage {
                Text(errorMessage)
                    .appText(.bodyXs)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .sheet(item: Binding<PaywallReason?>(
            get: { paywallReason.map(PaywallReason.init) },
            set: { paywallReason = $0?.text }
        )) { reason in
            PaywallSheet(reason: reason.text)
        }
    }

    private var hasLogo: Bool {
        race.logoData != nil || (race.logoURL?.isEmpty == false)
    }

    @ViewBuilder
    private var logoPreview: some View {
        let size: CGFloat = 64
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgTertiary)
            if let url = RaceLogoStore.fileURL(for: race) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.small)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Could not read image data."
                return
            }
            try RaceLogoStore.validate(data)
            // 旧 Documents ファイルや tmp キャッシュは新ロゴで上書きされるので掃除する
            RaceLogoStore.deleteLocalArtifacts(for: race)
            race.logoURL = nil
            race.logoData = data
        } catch {
            errorMessage = "Failed to save logo: \(error.localizedDescription)"
        }
    }

    /// クリップボードに画像があれば取り込む。Safari の "画像をコピー" やスクショ後のコピーに対応。
    /// 透過 PNG のときは PNG、それ以外は JPEG に降下して保存する。
    private func pasteImageFromClipboard() {
        errorMessage = nil
        let pasteboard = UIPasteboard.general
        guard pasteboard.hasImages, let image = pasteboard.image else {
            errorMessage = "No image on the clipboard."
            return
        }
        let imageData: Data? = image.pngData() ?? image.jpegData(compressionQuality: 0.9)
        guard let data = imageData else {
            errorMessage = "Could not encode pasted image."
            return
        }
        do {
            try RaceLogoStore.validate(data)
            RaceLogoStore.deleteLocalArtifacts(for: race)
            race.logoURL = nil
            race.logoData = data
        } catch {
            errorMessage = "Failed to save logo: \(error.localizedDescription)"
        }
    }
}
