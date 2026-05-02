import SwiftUI
import Photos
import UIKit

/// PHAsset.localIdentifier を非同期に解決してサムネを表示する。
///
/// 解決失敗時は "Photo unavailable" placeholder を表示。Photos 権限が無い／
/// 別デバイスのライブラリ ID（クロスデバイスでは解決不能）の場合に発生する。
struct PhotoAssetThumbnail: View {
    let localIdentifier: String
    let size: CGFloat

    @State private var image: UIImage? = nil
    @State private var assetMissing: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.bgTertiary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if assetMissing {
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                    Text("Unavailable")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: localIdentifier) {
            await load()
        }
    }

    private func load() async {
        // 権限要求は最初のアクセス時に遅延でかける（PhotosPicker 自体は権限不要）。
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            await MainActor.run { assetMissing = true }
            return
        }
        let scale = await MainActor.run { UIScreen.main.scale }
        let target = CGSize(width: size * scale, height: size * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let manager = PHCachingImageManager.default()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            manager.requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                if let result {
                    Task { @MainActor in
                        self.image = result
                    }
                }
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
        }
    }
}
