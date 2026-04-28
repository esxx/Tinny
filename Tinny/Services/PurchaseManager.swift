// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class PurchaseManager {
    private let premiumProductID = "premium"  // Change only if you update the product ID in App Store Connect

    var isPremium: Bool = false

    init() {
        // Load current entitlements (works offline)
        Task(priority: .background) {
            for await verificationResult in Transaction.currentEntitlements {
                await self.handle(verificationResult)
            }
        }
        // Listen for new transactions / restores
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                await self.handle(verificationResult)
            }
        }
    }

    private func handle(_ verificationResult: VerificationResult<Transaction>) async {
        switch verificationResult {
        case .verified(let transaction):
            if transaction.productID == premiumProductID {
                isPremium = transaction.revocationDate == nil
            }
            await transaction.finish()
        case .unverified(let transaction, _):
            await transaction.finish()
        }
    }

    // Called automatically by StoreView restore button
    func restorePurchases() async {
        try? await AppStore.sync()
    }
}
