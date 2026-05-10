import SwiftUI

/// 子ビューを左→右→必要なら次の行にラップする簡易レイアウト。
/// 凡例やタグ列など、要素数が動的でラップしてほしい場面で使う。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if currentLineWidth + s.width > width {
                totalHeight += currentLineHeight + spacing
                maxWidth = max(maxWidth, currentLineWidth - spacing)
                currentLineWidth = 0
                currentLineHeight = 0
            }
            currentLineWidth += s.width + spacing
            currentLineHeight = max(currentLineHeight, s.height)
        }
        totalHeight += currentLineHeight
        maxWidth = max(maxWidth, currentLineWidth - spacing)
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if origin.x + s.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            sv.place(at: origin, proposal: ProposedViewSize(s))
            origin.x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}
