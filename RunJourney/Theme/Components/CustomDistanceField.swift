import SwiftUI

/// `@AppStorage("customDistanceKm")` を編集する共通の TextField。
/// Settings と PaceCalculator で同じ入力体験を提供するため、書式・コミット・単位連動の
/// ロジックをここに集約する。プラットフォーム差分 (decimalPad keyboard) もここで吸収。
struct CustomDistanceField: View {
    @Binding var customDistanceKm: Double
    let unit: DistanceUnit
    /// 数値部の幅。Settings は flex、Pace は固定幅 (80) を使うため呼び出し側で指定。
    var fieldWidth: CGFloat? = nil
    /// プレースホルダ。省略時は単位ラベル ("km" / "mi")。
    var placeholder: String? = nil
    /// 末尾に単位ラベルを描くか。Settings: true, Pace: true。
    var showsUnitLabel: Bool = true

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 8) {
            field
            if showsUnitLabel {
                Text(unit.label)
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = formatted() }
        .onChange(of: unit) { _, _ in text = formatted() }
        .onChange(of: customDistanceKm) { _, _ in text = formatted() }
    }

    @ViewBuilder
    private var field: some View {
        let placeholderText = placeholder ?? unit.label
#if os(iOS)
        TextField(placeholderText, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.appFont(.codeBaseBold))
            .modifier(WidthModifier(width: fieldWidth))
            .onSubmit(commit)
#else
        TextField(placeholderText, text: $text)
            .multilineTextAlignment(.trailing)
            .font(.appFont(.codeBaseBold))
            .modifier(WidthModifier(width: fieldWidth))
            .onSubmit(commit)
#endif
    }

    private func formatted() -> String {
        let v = customDistanceKm.displayed(in: unit)
        return abs(v) >= 10 ? String(format: "%.1f", v) : String(format: "%.2f", v)
    }

    private func commit() {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(normalized), parsed > 0 else {
            text = formatted()
            return
        }
        customDistanceKm = parsed.toKm(from: unit)
        text = formatted()
    }
}

private struct WidthModifier: ViewModifier {
    let width: CGFloat?
    func body(content: Content) -> some View {
        if let w = width {
            content.frame(width: w)
        } else {
            content
        }
    }
}
