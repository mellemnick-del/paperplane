import StoreKit

/// The one in-app purchase: "Remove Ads" (non-consumable), through Apple's StoreKit 2.
/// Owning it hides interstitial ads and makes "smooth a crease" free, without a video.
@MainActor
final class Store: ObservableObject {
    static let removeAdsID = "com.nickmellem.paperplane.removeads"
    private static let ownedKey = "paperplane.adsRemoved"

    @Published private(set) var adsRemoved: Bool
    @Published private(set) var product: Product?
    @Published private(set) var busy = false

    private var updates: Task<Void, Never>?

    init() {
        adsRemoved = UserDefaults.standard.bool(forKey: Self.ownedKey)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlements()
        }
    }

    deinit { updates?.cancel() }

    /// Price as Apple formats it for the player's country, for example "$2.99".
    var price: String? { product?.displayPrice }

    func buy() async {
        if product == nil { await loadProduct() }
        guard let product, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result {
                await handle(verification)
            }
        } catch {
            // Purchase failed or was cancelled; nothing to undo.
        }
    }

    /// Apple requires a way to restore purchases on a new device.
    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func loadProduct() async {
        product = try? await Product.products(for: [Self.removeAdsID]).first
    }

    private func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.removeAdsID, t.revocationDate == nil {
                owned = true
            }
        }
        // Only ever turn it on from here; a refund comes through Transaction.updates.
        if owned { setOwned(true) }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else { return }
        if t.productID == Self.removeAdsID {
            setOwned(t.revocationDate == nil)
        }
        await t.finish()
    }

    private func setOwned(_ owned: Bool) {
        adsRemoved = owned
        UserDefaults.standard.set(owned, forKey: Self.ownedKey)
    }
}
