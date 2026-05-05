import SwiftUI

/// 5番目のトップレベルタブ "TOOLS"。
/// セグメント切替で `Calculator / Pace / Cheer Point` を内部に持つランナー向け汎用ツール。
struct ToolsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case calculator
        case pace
        case cheerPoint

        var id: String { rawValue }
        var label: String {
            switch self {
            case .calculator: return "Calculator"
            case .pace: return "Pace"
            case .cheerPoint: return "Cheer Point"
            }
        }
    }

    @State private var mode: Mode = .calculator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tools")
                    .appText(.displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .calculator:
                    TimeCalculatorView()
                case .pace:
                    PaceConverterView()
                case .cheerPoint:
                    CheerPointView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }
}

#Preview {
    NavigationStack { ToolsView() }
}
