import SwiftUI

/// マルチデバイス対応のための「画面の広さ」分類。
///
/// SwiftUI のサイズクラスはコンパクト/レギュラーの 2 値しかないが、本アプリは
/// レイアウトを「縦長 iPhone」「横向き iPhone」「iPad 縦持ち」「iPad 横持ち / Mac」の
/// 4 系統に分けたい。`EnvironmentValues.adaptiveLayout` で参照する形に統一しておくと、
/// 各 View がプラットフォーム判定を自前で書かずに済む。
///
/// iPad は縦/横どちらも `horizontalSizeClass = .regular` で見分けがつかないため、
/// `resolve(...)` には `containerWidth` を渡し、ウィンドウ幅で portrait/landscape を
/// 区別する (1050pt 未満を縦扱い: iPad Pro 13" 縦 1024pt も含めるしきい値)。
enum AdaptiveLayout: Equatable {
    /// iPhone 縦向き想定 (h: compact, v: regular)。
    case phonePortrait
    /// iPhone 横向き / 小さい iPad split window 等 (h: compact, v: compact)。
    /// 縦が狭いので、上部見出しを抑え左右に伸ばすレイアウトに切り替える指標。
    case phoneLandscape
    /// iPad 縦持ち。h:regular だが横幅が狭く、ペインを左右に並べると窮屈になる。
    /// 各画面は単段スクロールに戻し、グリッドのみ広めの列数を活かす。
    case padPortrait
    /// iPad 横持ち / Mac (h: regular, 横幅広め)。横にも縦にも余裕があるので多カラム化する指標。
    case wide

    /// "ガッツリ広い" 横向き iPad / Mac か。Map の永続サイドドロワーや Tools の
    /// 左ペイン+右コンテンツのような「水平 split」UI のオン/オフに使う。
    /// `padPortrait` は含めない (横幅が足りないので window を縦に切り直したい)。
    var isWide: Bool { self == .wide }

    /// h:regular 系か (= NavigationSplitView ベースの sidebar UX を採るべき iPad/Mac)。
    /// 縦持ち iPad でも sidebar からセクションを切替えたいので true にする。
    var usesSidebarRoot: Bool { self == .wide || self == .padPortrait }

    /// 縦が狭いか (= iPhone landscape)。上部の display ヘッダ等を控えめにする判断に使う。
    var isVerticallyCompact: Bool { self == .phoneLandscape }

    /// このレイアウトでセクションを横並びに切替えるべきか。
    /// `phoneLandscape` は左右が広いので 2 カラムに、iPad 縦は窮屈なので単段に戻す。
    var prefersMultiColumn: Bool {
        self == .wide || self == .phoneLandscape
    }

    /// LazyVGrid に渡す推奨カラム数 (StatCard 等の小カード向け)。
    /// 横向き iPhone と iPad 縦は 3、iPad 横/Mac は 4、それ以外は 2。
    var statCardColumnCount: Int {
        switch self {
        case .phonePortrait: return 2
        case .phoneLandscape: return 3
        case .padPortrait: return 3
        case .wide: return 4
        }
    }

    /// 中型カード (PB ボード等) の推奨カラム数。
    var mediumCardColumnCount: Int {
        switch self {
        case .phonePortrait: return 1
        case .phoneLandscape: return 2
        case .padPortrait: return 2
        case .wide: return 2
        }
    }

    /// コンテンツ最大幅。Mac / iPad で文字行が間延びするのを防ぐ。
    /// iPad 縦は単段中央寄せで読みやすい幅にクランプする。
    var contentMaxWidth: CGFloat? {
        switch self {
        case .wide: return 1_400
        case .padPortrait: return 880
        default: return nil
        }
    }

    /// 標準パディング。広い画面ほど余白を大きく取る。
    var standardPadding: CGFloat {
        switch self {
        case .phonePortrait: return 16
        case .phoneLandscape: return 20
        case .padPortrait: return 22
        case .wide: return 24
        }
    }

    /// `EnvironmentValues` に流すための解決ロジック。
    ///
    /// - Parameters:
    ///   - horizontal/vertical: SizeClass 由来の値。コンパクト判定に使う。
    ///   - containerWidth: ルート (ContentView) の `GeometryReader` から渡す
    ///     ウィンドウ実幅。h:regular な環境でこの値が 1050pt 未満なら
    ///     `padPortrait` (= iPad 縦) と見なす。`nil` のときは従来挙動 (= `.wide`) に倒す。
    static func resolve(
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?,
        containerWidth: CGFloat? = nil
    ) -> AdaptiveLayout {
        if horizontal == .regular {
            // iPad / Mac。縦持ち iPad は横幅が狭いので別ケースに振る。
            // しきい値 1050pt は iPad Pro 13" 縦 (1024pt) を縦扱いに含めるための値。
            if let w = containerWidth, w > 0, w < 1_050 {
                return .padPortrait
            }
            return .wide
        }
        if vertical == .compact {
            return .phoneLandscape
        }
        return .phonePortrait
    }
}

private struct AdaptiveLayoutKey: EnvironmentKey {
    static let defaultValue: AdaptiveLayout = .phonePortrait
}

extension EnvironmentValues {
    /// 各画面で `@Environment(\.adaptiveLayout)` で参照するエントリ。
    /// ルート (`ContentView`) で `.environment(\.adaptiveLayout, ...)` を流し込むことで
    /// 末端の View がサイズクラスを直接読まずにレイアウト分岐できる。
    var adaptiveLayout: AdaptiveLayout {
        get { self[AdaptiveLayoutKey.self] }
        set { self[AdaptiveLayoutKey.self] = newValue }
    }
}

/// SizeClass を読み取って `\.adaptiveLayout` に流し込むラッパ ViewModifier。
/// ルート View に `.adaptiveLayoutEnvironment()` で 1 回かけれぼ全子孫に行き渡る。
///
/// 注意: このモディファイア単独では containerWidth を計測しないため、iPad 縦/横を
/// 区別しない (= 常に `.wide` 扱い)。`ContentView` のように iPad の縦/横を分けたい
/// ところでは GeometryReader から `AdaptiveLayout.resolve(..., containerWidth:)` を
/// 直接呼んで `.environment(\.adaptiveLayout, ...)` する。
struct AdaptiveLayoutEnvironment: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    func body(content: Content) -> some View {
        let layout = AdaptiveLayout.resolve(horizontal: hSize, vertical: vSize)
        content.environment(\.adaptiveLayout, layout)
    }
}

extension View {
    func adaptiveLayoutEnvironment() -> some View {
        modifier(AdaptiveLayoutEnvironment())
    }

    /// コンテンツ幅を `AdaptiveLayout.contentMaxWidth` でクランプして中央寄せする。
    /// iPad の横向きや Mac の最大化ウィンドウで本文が果てしなく広がるのを防ぐ。
    @ViewBuilder
    func adaptiveContentWidth(_ layout: AdaptiveLayout) -> some View {
        if let maxW = layout.contentMaxWidth {
            self.frame(maxWidth: maxW)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }
}
