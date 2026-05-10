import SwiftUI

/// 小型のメトリクス表示カード (例: Total Distance, Finishes)。
/// アイコン + ラベル + 値 + 単位 の固定レイアウトで、`MetricGroupCard` と
/// `summaryGrid` から共通利用する。
struct StatCard: View {
    let label: String
    let value: String
    let unit: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.title2)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .appText(.codeMd)
                        .foregroundStyle(Color.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
