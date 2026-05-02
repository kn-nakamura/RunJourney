import SwiftUI
import Observation

/// アプリ起動時のスプラッシュ → マップ画面への引き渡しを司るオブザーバブル。
/// `RunJourneyApp` が `@State` で保持し、`.environment(...)` 経由で配布する。
/// マップ側で初回 fit-all アニメーションが始まる瞬間に `beginHandoff()` を呼ぶ。
@Observable
final class SplashCoordinator {
    enum Phase: Equatable {
        case splash      // 初期表示。ロゴ + タイトルが画面全体を覆う
        case fading      // フェードアウト中（map は背後で fit-all アニメ進行）
        case done        // overlay 撤去完了
    }

    private(set) var phase: Phase = .splash

    /// マップ側で初回フィットが始まったタイミングで呼ぶ。
    /// 0.7s フェード → 0.05s バッファ後に overlay を完全撤去。
    @MainActor
    func beginHandoff() {
        guard phase == .splash else { return }
        withAnimation(.easeOut(duration: 0.7)) {
            phase = .fading
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(.easeOut(duration: 0.1)) {
                phase = .done
            }
        }
    }
}
