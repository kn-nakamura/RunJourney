import SwiftUI
import SwiftData

/// Race Logo を URL で指定するための入力フィールド。
///
/// `RaceLogoStore.fileURL(for:)` は http(s) スキームを passthrough するので、
/// ここでは `race.logoURL` に URL 文字列を直接書き込むだけで良い。
/// 旧データのローカル画像 / 新データの `logoData` バイナリがあった場合は、
/// commit 時に掃除してから URL を上書きする。
struct RaceLogoUrlField: View {
    @Bindable var race: Race

    @State private var draft: String = ""

    private var hasURL: Bool {
        guard let value = race.logoURL else { return false }
        return value.hasPrefix("http://") || value.hasPrefix("https://")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("https://...", text: $draft)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { commit() }
                Button(action: commit) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(canCommit ? AnyShapeStyle(Color.accentPrimary) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
                .accessibilityLabel("Use URL")
            }
            if hasURL {
                Text(race.logoURL ?? "")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .onAppear {
            if hasURL {
                draft = race.logoURL ?? ""
            }
        }
    }

    private var canCommit: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return false }
        return true
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard canCommit else { return }
        // ローカルファイル / バイナリ / tmp キャッシュがあれば掃除してから URL を採用
        RaceLogoStore.deleteLocalArtifacts(for: race)
        race.logoData = nil
        race.logoURL = trimmed
    }
}
