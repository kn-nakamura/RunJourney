import SwiftUI
import SwiftData

/// Race Detail 画面の最上部に置く、ロゴ + 大会名 + カテゴリのヘッダー行。
///
/// `Form` の中で 1 行のセクションとして使うため、`Section { RaceHeaderView() }` 形式で挿入し、
/// 行余白を消す側で `.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)` を当てる。
struct RaceHeaderView: View {
    @Bindable var race: Race

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            logoBox
            VStack(alignment: .leading, spacing: 4) {
                if race.name.isEmpty {
                    Text("Untitled Race")
                        .appText(.bodyMdBold)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                } else {
                    // 動的文字列は Bebas Neue 不可（日本語グリフが無い）。
                    // DM Sans Bold 18pt 相当の `.bodyMdBold` を使う。
                    Text(race.name)
                        .appText(.bodyMdBold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    Image(systemName: race.category.symbolName)
                        .font(.caption)
                        .foregroundStyle(Color.accentPrimary)
                    Text(race.category.displayName)
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var logoBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgTertiary)
            if let url = RaceLogoStore.fileURL(for: race) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.small)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    case .failure:
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.tertiary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
