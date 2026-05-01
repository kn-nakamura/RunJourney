import SwiftUI

/// 再生コントロールバー。シーク・再生/一時停止・スキップ・速度切替。
struct PlaybackControls: View {
    @Bindable var controller: PlaybackController
    @Binding var followMode: Bool

    @State private var isScrubbing = false
    @State private var wasPlayingBeforeScrub = false

    var body: some View {
        VStack(spacing: 8) {
            // シークバー
            HStack(spacing: 8) {
                Text(formatDuration(controller.currentTime))
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)

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
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }

            // 操作ボタン
            HStack(spacing: 14) {
                Button { controller.skip(by: -30) } label: {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 22))
                }

                Button { controller.togglePlay() } label: {
                    Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentPrimary)
                }

                Button { controller.skip(by: 30) } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 22))
                }

                Spacer()

                speedMenu
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06))
        )
    }

    private var speedMenu: some View {
        Menu {
            ForEach(PlaybackController.speedPresets, id: \.self) { preset in
                Button {
                    controller.changeSpeed(preset)
                } label: {
                    HStack {
                        Text("\(formatSpeed(preset))×")
                        if controller.speed == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 14))
                Text("\(formatSpeed(controller.speed))×")
                    .font(.mono(13, bold: true))
            }
            .foregroundStyle(Color.accentPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.bgSecondary, in: Capsule())
        }
    }

    private func formatSpeed(_ s: Double) -> String {
        if s == s.rounded() { return "\(Int(s))" }
        return String(format: "%.1f", s)
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
