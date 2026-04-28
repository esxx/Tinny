// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import SwiftUI

struct HeaderView: View {
    // MARK: - Properties
    let chimeEnabled: Bool
    let nextChimeText: String
    let hasSelectedHours: Bool
    let isPremium: Bool
    let onToggleChime: () -> Void

    // MARK: - Animation State
    @State private var unlockScale: CGFloat = 1.0

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isPremium ? String(localized: "app_name_ext", bundle: .main) : String(localized: "app_name", bundle: .main))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: isPremium)
                .scaleEffect(unlockScale, anchor: .leading)
                .onChange(of: isPremium) { _, newValue in
                    guard newValue else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { unlockScale = 1.15 }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6).delay(0.2)) { unlockScale = 1.0 }
                }

            HStack(spacing: 12) {
                toggleSwitch

                VStack(alignment: .leading, spacing: 2) {
                    statusText
                }
            }

            Text("Follows system sound settings", bundle: .main)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Toggle Switch
    private var toggleSwitch: some View {
        ZStack {
            Capsule()
                .fill(chimeEnabled ? Color.blue : Color(.systemFill))
                .frame(width: 48, height: 28)
            Circle()
                .fill(.white)
                .frame(width: 22)
                .offset(x: chimeEnabled ? 10 : -10)
                .shadow(radius: 1)
        }
        .animation(.smooth(duration: 0.2), value: chimeEnabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: chimeEnabled)
        .onTapGesture { onToggleChime() }
        
    }
    
    // MARK: - Status Text
    private var statusText: some View {
        Group {
            if chimeEnabled {
                if hasSelectedHours {
                    Text(nextChimeText)
                } else {
                    Text("on_no_hours", bundle: .main)
                }
            } else {
                if hasSelectedHours {
                    Text("off", bundle: .main)
                } else {
                    Text("off_no_hours", bundle: .main)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HeaderView(
            chimeEnabled: true,
            nextChimeText: "Next chime at 14:00",
            hasSelectedHours: true,
            isPremium: false,
            onToggleChime: {}
        )

        HeaderView(
            chimeEnabled: false,
            nextChimeText: "Next chime at 14:00",
            hasSelectedHours: true,
            isPremium: true,
            onToggleChime: {}
        )

        HeaderView(
            chimeEnabled: false,
            nextChimeText: "Next chime at 14:00",
            hasSelectedHours: false,
            isPremium: false,
            onToggleChime: {}
        )
    }
    .padding()
}
