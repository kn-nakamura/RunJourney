import SwiftUI

/// 5番目のトップレベルタブ "TOOLS"。
/// セグメント切替で `Calculator / Pace / Cheer Point` を内部に持つランナー向け汎用ツール。
///
/// レイアウト:
/// - phonePortrait: 上部 segmented Picker + 下にツール本体 (従来通り)
/// - phoneLandscape: 上部 segmented Picker。横が広い分 padding を増やし読みやすくする。
/// - wide (iPad / Mac): 左サイドに垂直 List で 3 種を選び、右に選択中ツールを並列表示。
///   iPad/Mac は両手操作が想定外なので、segmented より垂直リストの方がタップ範囲が広い。
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
        var symbolName: String {
            switch self {
            case .calculator: return "function"
            case .pace: return "speedometer"
            case .cheerPoint: return "figure.wave"
            }
        }
        var summary: String {
            switch self {
            case .calculator: return "Time math: add, subtract, split."
            case .pace: return "Convert pace, time, and distance."
            case .cheerPoint: return "Predict where to cheer along the course."
            }
        }
    }

    @State private var mode: Mode = .calculator
    @Environment(\.adaptiveLayout) private var layout

    var body: some View {
        Group {
            if layout.isWide {
                wideLayout
            } else {
                stackedLayout
            }
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    // MARK: - iPhone (portrait & landscape)

    private var stackedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tools")
                    .appText(layout.isVerticallyCompact ? .displayMd : .displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Mode", selection: pickerBinding) {
                    ForEach(Mode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                modeContent
            }
            .padding(.horizontal, layout.standardPadding)
            .padding(.vertical, 16)
            .frame(maxWidth: layout.contentMaxWidth ?? .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - iPad / Mac

    /// 左に垂直リスト、右にツール本体。SplitView は `ContentView` 側で外側を担当しているので
    /// 内部はシンプルな HStack で十分。NavigationStack をネストしないことで sidebar の
    /// チェイン (column 3 つ) を避ける。
    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            modeListPanel
                .frame(width: 240)
                .background(Color.bgPrimary)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(mode.label)
                        .appText(.displayLg)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(mode.summary)
                        .appText(.bodySm)
                        .foregroundStyle(.secondary)
                    modeContent
                }
                .padding(.horizontal, layout.standardPadding)
                .padding(.vertical, 20)
                .frame(maxWidth: layout.contentMaxWidth ?? .infinity, alignment: .topLeading)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var modeListPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tools")
                .appText(.displayLg)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            VStack(spacing: 4) {
                ForEach(Mode.allCases) { m in
                    Button {
                        if m != mode { Haptics.tap() }
                        mode = m
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: m.symbolName)
                                .frame(width: 22)
                                .foregroundStyle(mode == m ? Color.accentPrimary : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.label)
                                    .appText(mode == m ? .bodyBaseBold : .bodyBase)
                                    .foregroundStyle(Color.textPrimary)
                                Text(m.summary)
                                    .appText(.bodyXs)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(mode == m ? Color.bgSecondary : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .calculator:
            TimeCalculatorView()
        case .pace:
            PaceConverterView()
        case .cheerPoint:
            CheerPointView()
        }
    }

    /// segmented Picker 用。値変更で軽い触覚を返す。
    private var pickerBinding: Binding<Mode> {
        Binding(
            get: { mode },
            set: { newValue in
                if newValue != mode { Haptics.tap() }
                mode = newValue
            }
        )
    }
}

#Preview {
    NavigationStack { ToolsView() }
}
