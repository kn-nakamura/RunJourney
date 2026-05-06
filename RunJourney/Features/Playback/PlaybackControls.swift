import SwiftUI

/// 再生コントロールバー。Rewind / Play / シークを 1 行にまとめる。スピード変更は Settings パネルへ。
struct PlaybackControls: View {
    @Bindable var controller: PlaybackController
    var onRewind: (() -> Void)? = nil

    @State private var isScrubbing = false
    @State private var wasPlayingBeforeScrub = false

    var body: some View {
        HStack(spacing: 8) {
            // 巻き戻し
            Button {
                controller.seek(to: 0)
                onRewind?()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            // 再生 / 一時停止 — シークバー横に収まる小サイズ
            Button { controller.togglePlay() } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Text(formatDuration(controller.currentTime))
                .appText(.codeXs)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Slider(
                value: Binding(
                    get: { controller.currentTime },
                    set: { newValue in controller.seek(to: newValue) }
                ),
                in: 0...max(controller.totalDuration, 0.001),
                onEditingChanged: { editing in
                    if editing {
                        wasPlayingBeforeScrub = controller.isPlaying
                        if controller.isPlaying { controller.pause() }
                        isScrubbing = true
                    } else {
                        isScrubbing = false
                        if wasPlayingBeforeScrub { controller.play() }
                    }
                }
            )
            .tint(Color.accentPrimary)

            Text(formatDuration(controller.totalDuration))
                .appText(.codeXs)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
