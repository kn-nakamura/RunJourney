import Foundation

/// アプリ内言語選択。Settings → Language で切替。
///
/// 設計:
/// - `system` … iOS の言語設定に追従 (`AppleLanguages` 上書きを解除)
/// - それ以外 … BCP-47 ロケール識別子 (例: `ja`, `en`, `pt-BR`) を保持し、端末設定と独立して固定
///
/// 切替時の効果:
/// 1. SwiftUI の `Text(LocalizedStringKey)` / `Text(LocalizedStringResource)` は
///    `RunJourneyApp` が注入する `.environment(\.locale, …)` で即時切替
/// 2. `String(localized:)` / `Bundle.main` 経由の参照は `AppleLanguages` UserDefaults
///    上書きで次の参照から新ロケールを返す
struct AppLanguage: Equatable, Identifiable, Hashable {
    /// `nil` = システム追従、それ以外 = 固定する BCP-47 識別子。
    let localeIdentifier: String?

    var id: String { rawValue }

    /// `@AppStorage` 用の永続化文字列。`system` は専用センチネル。
    var rawValue: String { localeIdentifier ?? "system" }

    /// Picker 表示用ラベル。
    /// - `.system` … 英語固定 ("System")
    /// - それ以外 … その言語自身での名前 (autonym)。"日本語", "Français", "한국어"…
    ///   こうすることで誤って外国語に切替えてしまったユーザーが、自分の言語を識別して戻せる。
    var label: String {
        guard let id = localeIdentifier else { return "System" }
        let locale = Locale(identifier: id)
        if let name = locale.localizedString(forIdentifier: id), !name.isEmpty {
            return name.localizedCapitalized
        }
        return id
    }

    static let system = AppLanguage(localeIdentifier: nil)

    static let userDefaultsKey = "appLanguage"
    /// iOS が読み取るシステム言語上書きキー。`String(localized:)` / Bundle.main 経由の参照に効く。
    static let appleLanguagesKey = "AppleLanguages"

    /// `@AppStorage` から読み出した raw 値を安全にデコード。空 / 未知値は `.system`。
    static func resolve(_ raw: String) -> AppLanguage {
        if raw.isEmpty || raw == "system" { return .system }
        return AppLanguage(localeIdentifier: raw)
    }

    /// アプリにバンドルされている言語リソースから選択候補を構築する。
    /// `Bundle.main.localizations` は .lproj として実体のあるロケールを返す
    /// (Base は除外)。先頭は常に `.system`。
    static func availableLanguages() -> [AppLanguage] {
        let codes = Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted()
        return [.system] + codes.map { AppLanguage(localeIdentifier: $0) }
    }

    /// `AppleLanguages` UserDefaults を現在の選択に合わせて更新する。
    /// `.system` のときはキーを削除し、iOS の言語設定に委ねる。
    static func applyToSystem(_ language: AppLanguage) {
        if let code = language.localeIdentifier {
            UserDefaults.standard.set([code], forKey: appleLanguagesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        }
    }
}
