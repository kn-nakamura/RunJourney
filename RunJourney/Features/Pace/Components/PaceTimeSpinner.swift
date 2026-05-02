import SwiftUI

/// 目標タイム / ペース用の上下三角ボタン付き数値スピナー。
/// (Web 版 GoalTimeSelector.tsx の SpinnerButton 部分の Swift 化)
struct PaceTimeSpinner: View {
    enum Mode {
        case goalTime    // H:MM:SS
        case pace        // M:SS
    }

    let title: String
    let mode: Mode
    /// 秒単位の値 (Goal Time なら 0..86399、Pace なら 120..900 程度)
    @Binding var seconds: Int
    /// ペース表示時に goalTime 派生表示する場合に渡す。nil なら表示しない。
    let derivedGoalTimeSeconds: Int?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch mode {
            case .goalTime:
                goalTimeSpinner
            case .pace:
                paceSpinner
            }

            // Reserve the derived-line slot even when nil so paired spinners share height.
            Text(derivedGoalTimeSeconds.map { "→ \(PaceUtils.formatTimeSimple($0))" } ?? "→ ")
                .appText(.codeXs)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(derivedGoalTimeSeconds == nil ? 0 : 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Goal time (H:MM:SS)

    private var goalTimeSpinner: some View {
        HStack(spacing: 4) {
            spinnerColumn(value: hours, onUp: { adjustHours(1) }, onDown: { adjustHours(-1) }, format: "%d")
            colon
            spinnerColumn(value: minutes, onUp: { adjustMinutes(1) }, onDown: { adjustMinutes(-1) }, format: "%02d")
            colon
            spinnerColumn(value: seconds_unit, onUp: { adjustSeconds(1) }, onDown: { adjustSeconds(-1) }, format: "%02d")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pace (M:SS)

    private var paceSpinner: some View {
        HStack(spacing: 4) {
            spinnerColumn(value: paceMin, onUp: { adjustPaceMinutes(1) }, onDown: { adjustPaceMinutes(-1) }, format: "%d")
            colon
            spinnerColumn(value: paceSec, onUp: { adjustPaceSeconds(1) }, onDown: { adjustPaceSeconds(-1) }, format: "%02d")
        }
        .frame(maxWidth: .infinity)
    }

    private var colon: some View {
        Text(":")
            .appText(.codeLg)
            .foregroundStyle(.secondary)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func spinnerColumn(
        value: Int,
        onUp: @escaping () -> Void,
        onDown: @escaping () -> Void,
        format: String
    ) -> some View {
        VStack(spacing: 2) {
            Button(action: onUp) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(String(format: format, value))
                .appText(.codeLgBold)
                .foregroundStyle(Color.textPrimary)
                .frame(minWidth: 32)
                .contentTransition(.numericText())
                .monospacedDigit()

            Button(action: onDown) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Goal time decomposition

    private var hours: Int { seconds / 3600 }
    private var minutes: Int { (seconds % 3600) / 60 }
    private var seconds_unit: Int { seconds % 60 }

    private func adjustHours(_ delta: Int) {
        let h = max(0, min(23, hours + delta))
        seconds = h * 3600 + minutes * 60 + seconds_unit
    }
    private func adjustMinutes(_ delta: Int) {
        var m = minutes + delta
        var h = hours
        if m < 0 { m += 60; h -= 1 }
        if m >= 60 { m -= 60; h += 1 }
        guard (0...23).contains(h) else { return }
        seconds = h * 3600 + m * 60 + seconds_unit
    }
    private func adjustSeconds(_ delta: Int) {
        var s = seconds_unit + delta
        var m = minutes
        var h = hours
        if s < 0 { s += 60; m -= 1 }
        if s >= 60 { s -= 60; m += 1 }
        if m < 0 { m += 60; h -= 1 }
        if m >= 60 { m -= 60; h += 1 }
        guard (0...23).contains(h) else { return }
        seconds = h * 3600 + m * 60 + s
    }

    // MARK: - Pace decomposition

    private var paceMin: Int { seconds / 60 }
    private var paceSec: Int { seconds % 60 }

    private func adjustPaceMinutes(_ delta: Int) {
        let m = max(2, min(15, paceMin + delta))
        seconds = m * 60 + paceSec
    }
    private func adjustPaceSeconds(_ delta: Int) {
        var s = paceSec + delta
        var m = paceMin
        if s < 0 { s += 60; m -= 1 }
        if s >= 60 { s -= 60; m += 1 }
        guard (2...15).contains(m) else { return }
        seconds = m * 60 + s
    }
}
