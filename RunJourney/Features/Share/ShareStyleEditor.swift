import SwiftUI

/// 共有シート上部に置く、テーマ / アクセント / フォーマット切替パネル。
/// PaceShareSheet / ResultShareSheet / MapShareSheet で再利用する。
struct ShareStyleEditor: View {
    @Binding var config: ShareStyleConfig
    /// シート開始時に解決した「現在のアプリ設定」。Reset to App Defaults で戻す先。
    let appDefaults: ShareStyleConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            themeRow
            accentRow
            formatRow
            resetRow
        }
        .padding(14)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Theme

    private var themeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THEME")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            Picker("Theme", selection: themeBinding) {
                ForEach(ShareTheme.allCases) { t in
                    Label(t.label, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// テーマ変更時に accent palette が合わなくなる場合は、選択中アクセントを
    /// 同テーマのデフォルトにフォールバックする。
    private var themeBinding: Binding<ShareTheme> {
        Binding(
            get: { config.theme },
            set: { newTheme in
                var next = config
                next.theme = newTheme
                if next.accent.palette != newTheme.appTheme {
                    next.accent = newTheme.appTheme.defaultAccent
                }
                config = next
            }
        )
    }

    // MARK: - Accent

    private var accentRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCENT")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                spacing: 10
            ) {
                ForEach(AccentChoice.options(for: config.theme.appTheme)) { choice in
                    Button {
                        config.accent = choice
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: choice.hex))
                                .frame(width: 32, height: 32)
                            Circle()
                                .strokeBorder(
                                    config.accent == choice ? Color.textPrimary : .clear,
                                    lineWidth: 2
                                )
                                .frame(width: 36, height: 36)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityLabel(choice.label)
                        .accessibilityAddTraits(config.accent == choice ? .isSelected : [])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Format

    private var formatRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FORMAT")
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(ShareFormat.allCases) { f in
                    Button {
                        config.format = f
                    } label: {
                        formatCell(f)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func formatCell(_ f: ShareFormat) -> some View {
        let active = config.format == f
        HStack(spacing: 10) {
            Image(systemName: f.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Color.accentPrimary : Color.textPrimary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(f.label)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                Text(f.subtitle)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            (active ? Color.accentPrimary.opacity(0.18) : Color.bgTertiary),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(active ? Color.accentPrimary : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Reset

    @ViewBuilder
    private var resetRow: some View {
        if config != appDefaults {
            Button {
                config = appDefaults
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Reset to app defaults")
                        .appText(.bodyXs)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
