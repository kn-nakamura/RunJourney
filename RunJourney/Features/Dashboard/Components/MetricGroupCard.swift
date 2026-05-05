import SwiftUI

/// Dashboard の Activity / Progress などで複数小カードをまとめる薄いラッパー。
/// 内部レイアウトは呼び出し側に任せ、共通の背景・余白・タイトル付与だけを担当する。
struct MetricGroupCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            content()
        }
    }
}
