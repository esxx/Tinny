// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import SwiftUI

struct SoundSelectionView: View {
    // MARK: - Properties
    let allSoundIDs: [String]
    let selectedSound: String
    let previewingID: String?
    let isPremium: Bool
    let store: SoundStore
    let onSelectSound: (String) -> Void
    let onDeleteCustom: (String) -> Void
    let onImportSound: () -> Void
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("sound", bundle: .main)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            soundList

            if selectedSound == SoundStore.speakingClockID {
                speakingClockHint
            }

            importButton

            supportedFormats
        }
    }
    
    // MARK: - Sound List
    private var soundList: some View {
        VStack(spacing: 0) {
            ForEach(Array(allSoundIDs.enumerated()), id: \.element) { i, soundID in
                let isSelected = selectedSound == soundID
                let isCustom = store.customSounds.contains { $0.id == soundID }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 16)
                        .opacity(isSelected ? 1 : 0)

                    Text(store.localizedName(for: soundID))
                        .font(.system(.subheadline, design: .rounded,
                                      weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)

                    Spacer()

                    if previewingID == soundID {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .symbolEffect(.variableColor.iterative)
                    } else if !isPremium && !SoundStore.freeSoundIDs.contains(soundID) && !isCustom {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isCustom {
                        Button(role: .destructive) {
                            onDeleteCustom(soundID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectSound(soundID)
                }

                if i < allSoundIDs.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Speaking Clock Hint

    private var speakingClockHint: some View {
        Text("speaking_clock_hint", bundle: .main)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Import Button
    private var importButton: some View {
        Button {
            onImportSound()
        } label: {
            Label("import_sound", systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
        }
    }
    
    // MARK: - Supported Formats
    private var supportedFormats: some View {
        Text("supported_formats", bundle: .main)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Preview

#Preview {
    SoundSelectionView(
        allSoundIDs: ["beeper", "bell", "chime"],
        selectedSound: "beeper",
        previewingID: nil,
        isPremium: false,
        store: .shared,
        onSelectSound: { _ in },
        onDeleteCustom: { _ in },
        onImportSound: {}
    )
    .padding()
}
