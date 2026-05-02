import SwiftUI

/// `H : MM : SS` を3つの NumberPad TextField で編集する小コンポーネント。
/// 単一の `Binding<Int>` (秒) を持つ。各フィールドは数値のみで桁数制限あり。
///
/// - 時間: 0–23
/// - 分・秒: 0–59
struct HMSField: View {
    @Binding var totalSeconds: Int
    var compactStyle: Bool = false

    @State private var hText: String = ""
    @State private var mText: String = ""
    @State private var sText: String = ""
    @FocusState private var focused: Field?

    private enum Field { case h, m, s }

    var body: some View {
        HStack(spacing: 6) {
            cell($hText, focus: .h, max: 23, width: compactStyle ? 38 : 48)
            colonLabel
            cell($mText, focus: .m, max: 59, width: compactStyle ? 38 : 48)
            colonLabel
            cell($sText, focus: .s, max: 59, width: compactStyle ? 38 : 48)
        }
        .onAppear { syncFromSeconds() }
        .onChange(of: totalSeconds) { _, _ in syncFromSeconds() }
    }

    private var colonLabel: some View {
        Text(":")
            .appText(.codeMd)
            .foregroundStyle(.secondary)
    }

    private func cell(_ text: Binding<String>, focus: Field, max: Int, width: CGFloat) -> some View {
        TextField("00", text: text)
#if os(iOS)
            .keyboardType(.numberPad)
#endif
            .multilineTextAlignment(.center)
            .font(.appFont(.codeLgBold))
            .foregroundStyle(Color.textPrimary)
            .frame(width: width)
            .padding(.vertical, 8)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 8))
            .focused($focused, equals: focus)
            .onChange(of: text.wrappedValue) { _, newVal in
                let cleaned = String(newVal.filter { $0.isNumber }.prefix(2))
                if cleaned != newVal { text.wrappedValue = cleaned }
                let value = Int(cleaned) ?? 0
                let clamped = min(value, max)
                if value != clamped {
                    text.wrappedValue = String(clamped)
                }
                pushToSeconds()
            }
    }

    private func syncFromSeconds() {
        let total = Swift.max(0, totalSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        hText = String(format: "%d", h)
        mText = String(format: "%02d", m)
        sText = String(format: "%02d", s)
    }

    private func pushToSeconds() {
        let h = Int(hText) ?? 0
        let m = Int(mText) ?? 0
        let s = Int(sText) ?? 0
        totalSeconds = h * 3600 + m * 60 + s
    }
}
