import SwiftUI

/// 起動時のブランドオーバーレイ。`UILaunchScreen` は背景色だけ
/// (`LaunchBackground`) を出しているので、OS の launch screen → SwiftUI の
/// 切替時に表示されるロゴはこの View だけ。
/// マップの初回 fit-all アニメーションが走るタイミングでフェードアウトする。
struct SplashView: View {
    @Environment(SplashCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("BrandLogo")
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.accentPrimary.opacity(0.18), radius: 20, y: 4)

                Text("Run Journey")
                    .appText(.displayLg)
                    .foregroundStyle(Color.textPrimary)
            }
            .scaleEffect(coordinator.phase == .splash ? 1.0 : 1.04)
            .opacity(coordinator.phase == .splash ? 1.0 : 0.0)
        }
        .allowsHitTesting(coordinator.phase != .done)
    }
}

#Preview {
    SplashView()
        .environment(SplashCoordinator())
}
