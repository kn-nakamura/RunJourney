import SwiftUI

/// TOOLS タブの結果表示用 dark gradient card。タイトル + メトリクス行のスロット。
struct ToolsResultCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .appText(.displaySm)
                .foregroundStyle(Color.textPrimary)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.bgSecondary, Color.bgTertiary],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

/// 結果メトリクス 1 行 (大数値 + 単位 + 補足)。
struct ToolsResultMetric: View {
    let value: String
    let unit: String?
    let detail: String?

    init(value: String, unit: String? = nil, detail: String? = nil) {
        self.value = value
        self.unit = unit
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .appText(.codeXl)
                .foregroundStyle(Color.accentPrimary)
            if let unit {
                Text(unit)
                    .appText(.codeSm)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let detail {
                Text(detail)
                    .appText(.codeSm)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
