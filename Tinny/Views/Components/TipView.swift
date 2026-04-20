// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import SwiftUI

struct TipView: View {
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("for_sound_only", bundle: .main)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 6) {
                Text("tip_instructions", bundle: .main)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach([
                    ("lock.fill", "lock_screen_off"),
                    ("list.bullet.rectangle.fill", "notification_centre_off"),
                    ("rectangle.topthird.inset.filled", "banners_off"),
                ], id: \.1) { icon, textKey in
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.caption2)
                            .frame(width: 14)
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey(textKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                settingsButton
            }
        }
    }
    
    // MARK: - Settings Button
    private var settingsButton: some View {
        Button {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text("open_settings", bundle: .main)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.top, 2)
    }
}

// MARK: - Preview

#Preview {
    TipView()
        .padding()
}
