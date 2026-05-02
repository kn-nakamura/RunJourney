import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// 大会(Race)のロゴ画像を PhotosPicker から選び、Documents/race-logos にローカル保存する。
/// `Race.logoURL` には Documents 起点の相対パスが入る。
struct LogoPicker: View {
    @Bindable var race: Race
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                logoPreview
                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            race.logoURL == nil ? "Choose Logo" : "Replace Logo",
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

                    if race.logoURL != nil {
                        Button(role: .destructive) {
                            RaceLogoStore.delete(race.logoURL)
                            race.logoURL = nil
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
    }

    @ViewBuilder
    private var logoPreview: some View {
        let size: CGFloat = 64
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgTertiary)
            if let url = RaceLogoStore.url(for: race.logoURL) {
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
            if let oldPath = race.logoURL { RaceLogoStore.delete(oldPath) }
            let relative = try RaceLogoStore.save(data, for: race.id)
            race.logoURL = relative
        } catch {
            errorMessage = "Failed to save logo: \(error.localizedDescription)"
        }
    }

    /// クリップボードに画像があれば取り込む。Safari の "画像をコピー" やスクショ後のコピーに対応。
    /// JPEG が無いケース (透過 PNG) もあるので、PNG → JPEG の順でフォールバックして保存する。
    private func pasteImageFromClipboard() {
        errorMessage = nil
        let pasteboard = UIPasteboard.general
        guard pasteboard.hasImages, let image = pasteboard.image else {
            errorMessage = "No image on the clipboard."
            return
        }
        let data: Data?
        let ext: String
        if let png = image.pngData() {
            data = png
            ext = "png"
        } else {
            data = image.jpegData(compressionQuality: 0.9)
            ext = "jpg"
        }
        guard let imageData = data else {
            errorMessage = "Could not encode pasted image."
            return
        }
        do {
            if let oldPath = race.logoURL { RaceLogoStore.delete(oldPath) }
            let relative = try RaceLogoStore.save(imageData, for: race.id, ext: ext)
            race.logoURL = relative
        } catch {
            errorMessage = "Failed to save logo: \(error.localizedDescription)"
        }
    }
}
