import SwiftUI

/// 1月〜12月の活動強度 (レース数) を 12 セルの帯で表示するヒートマップ。
/// 最大値を 1.0 に正規化して、`accentPrimary` の opacity で塗り分ける。
struct MonthHeatmapChart: View {
    let counts: [Int: Int]

    private var maxCount: Int {
        counts.values.max() ?? 0
    }

    private static let monthAbbrev = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                      "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    var body: some View {
        if counts.isEmpty {
            Text("No monthly data")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { m in
                    cell(month: m)
                }
            }
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { m in
                    Text(Self.monthAbbrev[m])
                        .appText(.codeXxs)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func cell(month: Int) -> some View {
        let count = counts[month] ?? 0
        let intensity: Double = maxCount > 0 ? Double(count) / Double(maxCount) : 0
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentPrimary.opacity(0.12 + 0.85 * intensity))
            if count > 0 {
                Text("\(count)")
                    .appText(.codeXxsBold)
                    .foregroundStyle(intensity > 0.55 ? .black : Color.accentPrimary)
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
    }
}
