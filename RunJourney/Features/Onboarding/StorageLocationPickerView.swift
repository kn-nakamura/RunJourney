import SwiftUI

/// 初回起動時に保存先を選んでもらうフルスクリーン picker。
///
/// `RunJourneyApp` から `hasChosen == false` の間だけ表示する。
/// 選択は `@AppStorage("storageLocation")` に書かれ、ModelContainer 構築時に反映される。
struct StorageLocationPickerView: View {
    /// ユーザーが選択したときに呼ばれる。
    let onSelect: (StorageLocation) -> Void

    /// iCloud にサインインしているか（オフ時は iCloud カードを disabled にする）。
    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 24)
                Text("Choose Storage")
                    .appText(.displayLg)
                    .foregroundStyle(Color.textPrimary)
                Text("Where should RunJourney save your races and results?")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    optionCard(
                        location: .iCloud,
                        recommended: true,
                        disabled: !iCloudAvailable,
                        disabledHint: "Sign in to iCloud in Settings to enable sync."
                    )
                    optionCard(
                        location: .local,
                        recommended: false,
                        disabled: false,
                        disabledHint: nil
                    )
                }

                Spacer()

                Text("You can change this later in Settings, but switching does not migrate existing data.")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func optionCard(
        location: StorageLocation,
        recommended: Bool,
        disabled: Bool,
        disabledHint: String?
    ) -> some View {
        Button {
            guard !disabled else { return }
            onSelect(location)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: location.systemImage)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(disabled ? Color.textMuted : Color.accentPrimary)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(location.displayName)
                            .appText(.bodyMdBold)
                            .foregroundStyle(Color.textPrimary)
                        if recommended {
                            Text("Recommended")
                                .appText(.eyebrow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentPrimary.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                    Text(location.detail)
                        .appText(.bodySm)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    if disabled, let hint = disabledHint {
                        Text(hint)
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
            .opacity(disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    StorageLocationPickerView { _ in }
}
