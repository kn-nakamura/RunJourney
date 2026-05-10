import SwiftUI

/// 再生設定パネル。アングル・回転・距離・スピード・追従スムージング・山強調を調整できる。
struct PlaybackSettingsPanel: View {
    @Bindable var controller: PlaybackController

    /// ユーザ上書き値。nil = プロファイル自動値。
    @Binding var userAngle: Double?
    @Binding var userDistance: Double?
    @Binding var userRotation: Double?
    @Binding var userCenterResponse: Double?
    @Binding var userBearingResponse: Double?

    /// 山強調設定 (raw 文字列)。@AppStorage 経由でバインド。
    @Binding var elevationEmphasisRaw: String

    /// プロファイルが示す自動値（スライダーの初期値として使う）
    let profileAngle: Double
    let profileDistance: Double
    let profileCenterResponse: Double
    let profileBearingResponse: Double

    // スライダー表示用のローカル状態 (nil は profile 値で初期化)
    @State private var localAngle: Double = 60
    @State private var localDistance: Double = 1500
    @State private var localRotation: Double = 0
    @State private var localCenterResp: Double = 0.26
    @State private var localBearingResp: Double = 1.5

    private var emphasis: ElevationEmphasis {
        ElevationEmphasis(rawValue: elevationEmphasisRaw) ?? .high
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Angle (0..180, 0=後方地面, 90=真上, 180=前方地面)
            rowSlider(
                label: "Angle",
                value: $localAngle,
                range: 0...180,
                format: "%.0f°"
            ) { localAngle = $0; userAngle = $0 }

            // Rotation (-180..180, 0=進行方向, +=右側から見る, -=左側から見る)
            rowSlider(
                label: "Rotation",
                value: $localRotation,
                range: -180...180,
                format: "%.0f°"
            ) { localRotation = $0; userRotation = $0 }

            // Camera Distance
            rowSlider(
                label: "Distance",
                value: $localDistance,
                range: 300...8000,
                format: "%.0f m"
            ) { localDistance = $0; userDistance = $0 }

            Divider().background(.white.opacity(0.1))

            // Mountain Emphasis (山の高低差をカメラトリックで擬似強調)
            elevationEmphasisRow

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
        .onChange(of: profileAngle) { _, _ in if userAngle == nil { localAngle = profileAngle } }
        .onChange(of: profileDistance) { _, _ in if userDistance == nil { localDistance = profileDistance } }
    }

    // MARK: - Mountain Emphasis row

    private var elevationEmphasisRow: some View {
        // ユーザが Angle / Distance を手動上書き中は、emphasis を変えても表面上効果が見えないので
        // dim して理由を伝える。emphasis は profile 既定値だけを動かすので override 中はノーオペ。
        let isOverridden = (userAngle != nil) || (userDistance != nil)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Mountain Emphasis")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Spacer()
                if isOverridden {
                    Text("Override active")
                        .appText(.bodyXs)
                        .foregroundStyle(Color.textMuted)
                }
            }
            Picker("Mountain Emphasis", selection: $elevationEmphasisRaw) {
                ForEach(ElevationEmphasis.allCases) { e in
                    Text(e.label).tag(e.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isOverridden)
            .opacity(isOverridden ? 0.4 : 1.0)
        }
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
        localAngle = userAngle ?? profileAngle
        localDistance = userDistance ?? profileDistance
        localRotation = userRotation ?? 0
        localCenterResp = userCenterResponse ?? profileCenterResponse
        localBearingResp = userBearingResponse ?? profileBearingResponse
    }

    private func resetToAuto() {
        userAngle = nil
        userDistance = nil
        userRotation = nil
        userCenterResponse = nil
        userBearingResponse = nil
        localAngle = profileAngle
        localDistance = profileDistance
        localRotation = 0
        localCenterResp = profileCenterResponse
        localBearingResp = profileBearingResponse
    }

    private func formatSpeed(_ s: Double) -> String {
        if s == s.rounded() { return "\(Int(s))" }
        return String(format: "%.1f", s)
    }
}
