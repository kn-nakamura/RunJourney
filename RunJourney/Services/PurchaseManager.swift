import Foundation
import StoreKit

/// アプリ内課金 (StoreKit 2) を統括する Observable。
///
/// 商品構成:
/// - **Premium 一括買い切り** (`runjourney.premium`): 添付バイナリ保存 / 無制限の
///   Race・Result 登録などの gate を解除する Non-Consumable。
/// - **Tip Jar** (`runjourney.tip.{small,medium,large}`): 機能制限を伴わない任意の支援。
///   Consumable なので `Transaction.currentEntitlements` には残らず、累積回数のみ
///   UserDefaults に記録する（「いつもありがとうございます」程度の演出用）。
///
/// 利用方法:
///   @Environment(PurchaseManager.self) var purchases  // ContentView 内
///   purchases.hasPremium       // gate 判定
///   purchases.product(for: .premium)
///   try await purchases.purchase(.premium)
///   try await purchases.restore()
///
/// `RunJourneyApp` で 1 回だけインスタンス化し、`.environment()` で全画面に流し込む。
/// `loadProducts()` と `listenForTransactions()` は init で開始する。
@Observable
@MainActor
final class PurchaseManager {

    // MARK: - Product IDs

    /// 自前の Product ID 一覧。App Store Connect および StoreKit Configuration ファイルの
    /// 文字列とこの enum の rawValue が完全一致している必要がある。
    enum ProductID: String, CaseIterable {
        case premium    = "runjourney.premium"
        case tipSmall   = "runjourney.tip.small"
        case tipMedium  = "runjourney.tip.medium"
        case tipLarge   = "runjourney.tip.large"

        var isTip: Bool {
            switch self {
            case .tipSmall, .tipMedium, .tipLarge: return true
            case .premium:                          return false
            }
        }
    }

    // MARK: - State

    /// App Store / StoreKit Configuration から取得した商品。空配列 = 取得前または失敗。
    private(set) var products: [Product] = []
    /// Premium 権利が付与済みか。`Transaction.currentEntitlements` を毎回再評価して反映。
    private(set) var hasPremium: Bool = false
    /// 商品取得中か。Settings で spinner 表示する用。
    private(set) var isLoading: Bool = false
    /// 直近のロード or 購入時のエラーメッセージ。UI に表示される。
    private(set) var errorMessage: String?

    /// Tip Jar 累積回数。Premium とは独立に UserDefaults に記録。
    private(set) var tipCount: Int = UserDefaults.standard.integer(forKey: tipCountKey)

    // MARK: - Internals

    /// 起動中ずっと回す `Transaction.updates` リスナ。プロモーション購入や
    /// 別端末で行われた購入の同期がここから流れてくる。
    private var transactionListener: Task<Void, Never>?
    private static let tipCountKey = "runjourney.purchase.tipCount"

    init() {
        transactionListener = startListeningForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Loading

    /// App Store から商品情報を取得する。アプリ起動時 / Settings 表示時に呼ぶ。
    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let identifiers = Set(ProductID.allCases.map(\.rawValue))
            let fetched = try await Product.products(for: identifiers)
            // Premium → tipSmall → tipMedium → tipLarge の順に並べる（UI 表示順を安定させる）
            self.products = fetched.sorted { lhs, rhs in
                let order: [String: Int] = ProductID.allCases.enumerated()
                    .reduce(into: [:]) { $0[$1.element.rawValue] = $1.offset }
                return (order[lhs.id] ?? .max) < (order[rhs.id] ?? .max)
            }
            self.errorMessage = nil
            await refreshEntitlements()
        } catch {
            self.errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    /// 指定 ID に対応する `Product` を返す。未取得時は nil。
    func product(for id: ProductID) -> Product? {
        products.first(where: { $0.id == id.rawValue })
    }

    // MARK: - Purchase

    /// Premium または Tip 商品の購入フローを起動する。
    /// 成功時は `hasPremium` または `tipCount` が更新される。
    @discardableResult
    func purchase(_ id: ProductID) async throws -> Bool {
        guard let product = product(for: id) else {
            throw PurchaseError.productNotLoaded
        }
        return try await purchase(product)
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await applyTransaction(transaction)
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// 「購入を復元」ボタン用。別端末で買った Premium をこの端末に再同期する。
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// 現在有効な権利を `Transaction.currentEntitlements` から再評価して `hasPremium` を更新する。
    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == ProductID.premium.rawValue {
                premium = true
            }
        }
        self.hasPremium = premium
    }

    // MARK: - Listener

    /// アプリ生存期間中ずっと走らせて、外部要因 (プロモオファー受け取り / 別端末同期) で
    /// 流れてくるトランザクションを順次取り込む。
    private nonisolated func startListeningForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                await self.applyTransaction(transaction)
                await transaction.finish()
            }
        }
    }

    private func applyTransaction(_ transaction: Transaction) async {
        if transaction.productID == ProductID.premium.rawValue {
            self.hasPremium = true
        }
        if let id = ProductID(rawValue: transaction.productID), id.isTip {
            self.tipCount += 1
            UserDefaults.standard.set(self.tipCount, forKey: Self.tipCountKey)
        }
        // 念のため最新エンタイトルメントも reconcile
        await refreshEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}

// MARK: - Error

enum PurchaseError: LocalizedError {
    case productNotLoaded

    var errorDescription: String? {
        switch self {
        case .productNotLoaded:
            return "Product information is not loaded yet. Please try again in a moment."
        }
    }
}
