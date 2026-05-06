import Foundation
import CloudKit
import Observation

/// iCloud アカウントが使える状態かを監視し、SwiftUI から observe できる形で公開する。
///
/// SwiftData の CloudKit ミラーリング自体はバックグラウンドでサイレントに動くため、
/// 同期が機能しない原因（iCloud 未サインイン / 権限制限）をユーザーが気付けるよう
/// Settings 画面に状態を出すための軽量ステータスチェッカ。
@Observable
@MainActor
final class CloudKitAccountMonitor {

    /// 直近に確認した CloudKit アカウント状態。`unknown` は初回確認前。
    enum Status: Equatable {
        case unknown
        case available
        case noAccount
        case restricted
        case couldNotDetermine
        case temporarilyUnavailable

        init(_ ck: CKAccountStatus) {
            switch ck {
            case .available:               self = .available
            case .noAccount:               self = .noAccount
            case .restricted:              self = .restricted
            case .temporarilyUnavailable:  self = .temporarilyUnavailable
            case .couldNotDetermine:       self = .couldNotDetermine
            @unknown default:              self = .couldNotDetermine
            }
        }

        var label: String {
            switch self {
            case .unknown:                 return "Checking..."
            case .available:               return "Sync Active"
            case .noAccount:               return "Not Signed In"
            case .restricted:              return "Restricted"
            case .couldNotDetermine:       return "Unavailable"
            case .temporarilyUnavailable:  return "Temporarily Unavailable"
            }
        }

        var detail: String {
            switch self {
            case .unknown:
                return "Checking iCloud account..."
            case .available:
                return "Records mirror to iCloud automatically. Other devices on the same Apple ID will receive new data."
            case .noAccount:
                return "Sign in to iCloud in the Settings app to enable sync."
            case .restricted:
                return "iCloud is restricted on this device (e.g. by Screen Time or a configuration profile)."
            case .couldNotDetermine:
                return "Could not contact iCloud. Check your network connection and try again."
            case .temporarilyUnavailable:
                return "iCloud is temporarily unavailable. Sync will resume automatically when it recovers."
            }
        }

        /// 良好かどうか（アクセントカラー判断に使う）。
        var isHealthy: Bool { self == .available }
    }

    private(set) var status: Status = .unknown
    private(set) var lastChecked: Date?

    private let container: CKContainer
    /// `for await` のリスナタスク。本オブジェクトはアプリ生存期間を通じて存在するシングルトン
    /// 用途のため、明示的に cancel する deinit は不要（self が deallocate された次のイベントで
    /// `weak self` が nil になり Task は自然終了する）。
    private var notificationTask: Task<Void, Never>?

    init(containerIdentifier: String = "iCloud.com.kn-nakamura.RunJourney") {
        self.container = CKContainer(identifier: containerIdentifier)
    }

    /// アカウント状態を取り直す。Settings 画面が表示された直後や pull-to-refresh で呼ぶ。
    func refresh() async {
        do {
            let raw = try await container.accountStatus()
            self.status = Status(raw)
        } catch {
            self.status = .couldNotDetermine
        }
        self.lastChecked = .now
    }

    /// `CKAccountChangedNotification` を購読して状態を自動更新する。
    /// 一度だけ呼べばよい（再呼び出しは no-op）。
    func startObserving() {
        guard notificationTask == nil else { return }
        notificationTask = Task { [weak self] in
            let stream = NotificationCenter.default.notifications(named: .CKAccountChanged)
            for await _ in stream {
                guard let self else { return }
                await self.refresh()
            }
        }
    }
}
