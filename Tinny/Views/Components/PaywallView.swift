// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import SwiftUI
import StoreKit

struct PaywallView: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Complete the Experience")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("Because your time is worth more")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("All built-in sounds")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Make it yours - bring your own sounds")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Speaking clock - hear the time aloud")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Chime every 15 or 30 minutes")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Weekdays or weekends only")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("One-time purchase • Own forever")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("No tracking • No accounts • Private")
                }
            }
            .font(.system(.subheadline, design: .rounded))

            StoreView(ids: ["premium"])
                .storeButton(.hidden, for: .cancellation)
                .storeButton(.visible, for: .restorePurchases)

            Text("paywall_tagline", bundle: .main)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
}
