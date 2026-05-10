import Foundation

extension Bundle {
    /// `CFBundleShortVersionString`。未取得時は "—"。
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// `CFBundleVersion`。未取得時は "—"。
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
