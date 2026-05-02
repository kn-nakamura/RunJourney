import SwiftUI

/// Splits 表の 1 ラップだけペースを書き換えるための編集シート。
///
/// - 上下三角ボタンで M / SS を独立に調整 (PaceTimeSpinner と同じ操作感を踏襲)
/// - "OK" でコミット、"Cancel" で破棄、上書き済みのときだけ "Reset" を表示
/// - 派生ラップタイム (= pace × segmentKm) をリアルタイムプレビュー
struct LapPaceEditor: View {
    let lap: PaceLapSegment
    let initialPace: Int
    let onCancel: () -> Void
    let onCommit: (Int) -> Void
    let onReset: () -> Void

    @State private var pace: Int
    @State private var focusedField: Field = .minutes

    private enum Field { case minutes, seconds }

    init(
        lap: PaceLapSegment,
        initialPace: Int,
        onCancel: @escaping () -> Void,
        onCommit: @escaping (Int) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.lap = lap
        self.initialPace = initialPace
        self.onCancel = onCancel
        self.onCommit = onCommit
        self.onReset = onReset
        self._pace = State(initialValue: initialPace)
    }

    private var paceMin: Int { pace / 60 }
    private var paceSec: Int { pace % 60 }
    private var lapTimeSec: Int { Int((Double(pace) * lap.segmentKm).rounded()) }
    /// このラップが (現在 or 既存で) ベースペースと異なる = リセット可能。
    private var isOverridden: Bool { pace != lap.pacePerKm || initialPace != lap.pacePerKm }

    private var lapHeading: String {
        switch lap.distanceLabel {
        case "HALF", "GOAL": return lap.distanceLabel
        default:              return "\(lap.distanceLabel) km"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Edit Lap Pace")
                    .appText(.eyebrow)
                    .foregroundStyle(.secondary)
                Text(lapHeading)
                    .appText(.displayMd)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.top, 28)

            paceDial

            HStack(spacing: 24) {
                summaryCell(label: "Pace / km", value: PaceUtils.formatPaceSimple(pace))
                summaryCell(label: "Lap Time",  value: PaceUtils.formatTimeSimple(lapTimeSec))
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .appText(.bodyBaseBold)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    onCommit(pace)
                } label: {
                    Text("OK")
                        .appText(.bodyBaseBold)
                        .foregroundStyle(Color.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentPrimary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // 固定スロット: 上書き時のみ操作可能、非上書き時は不可視のまま高さを保持。
            Button(action: onReset) {
                Text("Reset to base pace")
                    .appText(.bodySm)
                    .foregroundStyle(Color.accentPrimary)
            }
            .buttonStyle(.plain)
            .opacity(isOverridden ? 1 : 0)
            .allowsHitTesting(isOverridden)
            .accessibilityHidden(!isOverridden)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgPrimary)
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }

    private var paceDial: some View {
        HStack(spacing: 18) {
            spinnerColumn(
                title: "MIN",
                value: paceMin,
                format: "%d",
                onUp: { adjustMinutes(1) },
                onDown: { adjustMinutes(-1) },
                isFocused: focusedField == .minutes,
                onTap: { focusedField = .minutes }
            )
            Text(":")
                .appText(.codeXl)
                .foregroundStyle(.secondary)
            spinnerColumn(
                title: "SEC",
                value: paceSec,
                format: "%02d",
                onUp: { adjustSeconds(1) },
                onDown: { adjustSeconds(-1) },
                isFocused: focusedField == .seconds,
                onTap: { focusedField = .seconds }
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func spinnerColumn(
        title: String,
        value: Int,
        format: String,
        onUp: @escaping () -> Void,
        onDown: @escaping () -> Void,
        isFocused: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            Button(action: onUp) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 56, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                Text(String(format: format, value))
                    .appText(.codeXl)
                    .foregroundStyle(isFocused ? Color.bgPrimary : Color.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(width: 80, height: 56)
                    .background(
                        isFocused ? Color.accentPrimary : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onDown) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 56, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            Text(value)
                .appText(.codeLgBold)
                .foregroundStyle(Color.accentPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Adjusters (clamp to 2:00..15:59)

    private func adjustMinutes(_ delta: Int) {
        let m = max(2, min(15, paceMin + delta))
        pace = m * 60 + paceSec
        focusedField = .minutes
    }

    private func adjustSeconds(_ delta: Int) {
        var s = paceSec + delta
        var m = paceMin
        if s < 0 { s += 60; m -= 1 }
        if s >= 60 { s -= 60; m += 1 }
        guard (2...15).contains(m) else { return }
        pace = m * 60 + s
        focusedField = .seconds
    }
}
