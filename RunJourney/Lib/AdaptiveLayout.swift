import SwiftUI

/// マルチデバイス対応のための「画面の広さ」分類。
///
/// SwiftUI のサイズクラスはコンパクト/レギュラーの 2 値しかないが、本アプリは
/// レイアウトを「縦長 iPhone」「横向き iPhone」「iPad / Mac」の 3 系統に分けたい。
/// `EnvironmentValues.adaptiveLayout` で参照する形に統一しておくと、各 View が
/// プラットフォーム判定を自前で書かずに済む。
enum AdaptiveLayout: Equatable {
    /// iPhone 縦向き想定 (h: compact, v: regular)。
    case phonePortrait
    /// iPhone 横向き / 小さい iPad split window 等 (h: compact, v: compact)。
    /// 縦が狭いので、上部見出しを抑え左右に伸ばすレイアウトに切り替える指標。
    case phoneLandscape
    /// iPad / Mac (h: regular)。横にも縦にも余裕があるので多カラム化する指標。
    case wide

    /// レギュラー幅か (= iPad / Mac)。
    var isWide: Bool { self == .wide }

    /// 縦が狭いか (= iPhone landscape)。上部の display ヘッダ等を控えめにする判断に使う。
    var isVerticallyCompact: Bool { self == .phoneLandscape }

    /// このレイアウトでセクションを横並びに切替えるべきか。
    /// `phoneLandscape` も対象に含める (左右が広いので 2 カラムが見やすい)。
    var prefersMultiColumn: Bool {
        self == .wide || self == .phoneLandscape
    }

    /// LazyVGrid に渡す推奨カラム数 (StatCard 等の小カード向け)。
    /// 横向き iPhone は 3、iPad は 4、それ以外は 2。
    var statCardColumnCount: Int {
        switch self {
        case .phonePortrait: return 2
        case .phoneLandscape: return 3
        case .wide: return 4
        }
    }

    /// 中型カード (PB ボード等) の推奨カラム数。
    var mediumCardColumnCount: Int {
        switch self {
        case .phonePortrait: return 1
        case .phoneLandscape: return 2
        case .wide: return 2
        }
    }

    /// コンテンツ最大幅。Mac / iPad で文字行が間延びするのを防ぐ。
    var contentMaxWidth: CGFloat? {
        switch self {
        case .wide: return 1_400
        default: return nil
        }
    }

    /// 標準パディング。広い画面ほど余白を大きく取る。
    var standardPadding: CGFloat {
        switch self {
        case .phonePortrait: return 16
        case .phoneLandscape: return 20
        case .wide: return 24
        }
    }

    /// `EnvironmentValues` に流すための解決ロジック。
    /// SizeClass のみで判定すると iPad の split view が compact になった瞬間に
    /// `phonePortrait` 扱いになり全画面のレイアウトが切り替わってしまうが、
    /// それは「画面の使える幅が iPhone 並み」になった時の意図通りの挙動なので
    /// ここでも素直にサイズクラスベースで分類する。
    static func resolve(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) -> AdaptiveLayout {
        if horizontal == .regular {
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
