import SwiftUI

/// 再生設定パネル。ピッチ・距離・スピード・追従スムージングを調整できる。
struct PlaybackSettingsPanel: View {
    @Bindable var controller: PlaybackController

    /// ユーザ上書き値。nil = プロファイル自動値。
    @Binding var userPitch: Double?
    @Binding var userDistance: Double?
    @Binding var userCenterResponse: Double?
    @Binding var userBearingResponse: Double?

    /// プロファイルが示す自動値（スライダーの初期値として使う）
    let profilePitch: Double
    let profileDistance: Double
    let profileCenterResponse: Double
    let profileBearingResponse: Double

    // スライダー表示用のローカル状態 (nil は profile 値で初期化)
    @State private var localPitch: Double = 60
    @State private var localDistance: Double = 1500
    @State private var localCenterResp: Double = 0.26
    @State private var localBearingResp: Double = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Pitch
            rowSlider(
                label: "Pitch",
                value: $localPitch,
                range: 0...85,
                format: "%.0f°"
            ) { localPitch = $0; userPitch = $0 }

            // Camera Distance
            rowSlider(
                label: "Distance",
                value: $localDistance,
                range: 300...8000,
                format: "%.0f m"
            ) { localDistance = $0; userDistance = $0 }

            Divider().background(.white.opacity(0.1))

            // Speed buttons
            VStack(alignment: .leading, spacing: 4) {
                Text("Speed")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                speedGrid
            }

            Divider().background(.white.opacity(0.1))

            // Follow Smoothing
            rowSlider(
                label: "Follow Smooth",
                value: $localCenterResp,
                range: 0.05...1.0,
                format: "%.2f s"
            ) { localCenterResp = $0; userCenterResponse = $0 }

            // Turn Smoothing
            rowSlider(
                label: "Turn Smooth",
                value: $localBearingResp,
                range: 0.05...5.0,
                format: "%.2f s"
            ) { localBearingResp = $0; userBearingResponse = $0 }

            // Reset to Auto
            Button {
                resetToAuto()
            } label: {
                Text("Reset to Auto")
                    .appText(.bodyXs)
                    .foregroundStyle(Color.accentPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06)))
        .onAppear { initLocals() }
        .onChange(of: profilePitch) { _, _ in if userPitch == nil { localPitch = profilePitch } }
        .onChange(of: profileDistance) { _, _ in if userDistance == nil { localDistance = profileDistance } }
    }

    // MARK: - Speed grid

    private var speedGrid: some View {
        let presets = PlaybackController.speedPresets
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
            spacing: 6
        ) {
            ForEach(presets, id: \.self) { preset in
                let isActive = controller.speed == preset
                Button {
                    controller.changeSpeed(preset)
                } label: {
                    Text("\(formatSpeed(preset))×")
                        .appText(.codeXsBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isActive ? Color.accentPrimary : Color.bgSecondary,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(isActive ? Color.black : Color.textPrimary)
                }
            }
        }
    }

    // MARK: - Row helper

    private func rowSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack {
            Text(label)
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Slider(value: value, in: range)
                .tint(Color.accentPrimary)
                .onChange(of: value.wrappedValue) { _, v in onChange(v) }
            Text(String(format: format, value.wrappedValue))
                .appText(.codeXs)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 58, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func initLocals() {
        localPitch = userPitch ?? profilePitch
        localDistance = userDistance ?? profileDistance
        localCenterResp = userCenterResponse ?? profileCenterResponse
        localBearingResp = userBearingResponse ?? profileBearingResponse
    }

    private func resetToAuto() {
        userPitch = nil
        userDistance = nil
        userCenterResponse = nil
        userBearingResponse = nil
        localPitch = profilePitch
        localDistance = profileDistance
        localCenterResp = profileCenterResponse
        localBearingResp = profileBearingResponse
    }

    private func formatSpeed(_ s: Double) -> String {
        if s == s.rounded() { return "\(Int(s))" }
        return String(format: "%.1f", s)
    }
}
