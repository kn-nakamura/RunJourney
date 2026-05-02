import SwiftUI

// MARK: - L2 Section Header (中タイトル)
//
// アプリ全体のセクション見出しを単一定義する View。
// - Bebas Neue 24pt UPPERCASE (`.displayMd`) — 大タイトル `.displayLg` (30pt) のひとつ下の階層
// - 任意の subtitle は DM Sans 12pt tertiary。タイトルと first-text-baseline で揃う。
// - Form の `Section { } header: { SectionHeader(title: ...) }` でも、ScrollView+VStack 直下でも
//   そのまま使える。Form 由来のデフォルト灰色を上書きするため `Color.textPrimary` を明示的に当てる。
//
// 文字列ルール: title は English ASCII 固定。Bebas Neue は日本語グリフを持たないので、
// 動的（race.name 等）には使わない（必要なら DM Sans の `.bodyBaseBold` を直接当てる）。

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .appText(.displayMd)
                .foregroundStyle(Color.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        // Form の `header:` スロットに渡されると SwiftUI が自動で uppercase を再適用するが、
        // token 側で適用済みなので無害。textCase(nil) を強制すると意図しない場面で崩れるため触らない。
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: "Personal Bests", subtitle: "by category")
        SectionHeader(title: "Library")
        SectionHeader(title: "Races per Year")
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
