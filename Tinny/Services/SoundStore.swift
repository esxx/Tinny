// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import Foundation
import Observation
import AVFoundation

@Observable
final class SoundStore {
    static let shared = SoundStore()
    
    // Built-in sounds from Asset Catalog (speakingclock is generated via TTS)
    static let builtInSounds = [
        "beeper", "windchimes", "buddhabowl", "callbell", "cuckooclock",
        "bell", "bowl", "courant", "grandfatherclock", "publicannouncement",
        "shipsbell", "strikingclock", "tibetanbell", "speakingclock", "pips"
    ]

    // MARK: - Free vs Pro Sounds (centralized single source of truth)
    static let freeSoundIDs: Set<String> = ["beeper", "windchimes", "buddhabowl", "callbell", "cuckooclock"]

    // Speaking clock is a virtual sound — has no bundle file
    static let speakingClockID = "speakingclock"

    // MARK: - Custom Sound Limit (single source of truth)
    static let customSoundLimit = 3
    
    var customSounds: [Sound] = []
    private let customSoundsKey = "customSounds_v4"
    
    @ObservationIgnored private var _customSoundsDir: URL?
    var customSoundsDir: URL {
        if let url = _customSoundsDir { return url }
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomSounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _customSoundsDir = url
        return url
    }

    @ObservationIgnored private var _libSoundsDir: URL??
    var libSoundsDir: URL? {
        if let cached = _libSoundsDir { return cached }
        guard let lib = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first
        else {
            _libSoundsDir = .some(nil)
            return nil
        }
        let url = lib.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _libSoundsDir = .some(url)
        return url
    }
    
    init() { load() }
    
    // MARK: - Sound Management
    
    func previewURL(for soundID: String) -> URL? {
        // Speaking clock: return (or generate) the current hour's TTS file
        if soundID == SoundStore.speakingClockID {
            guard let dir = libSoundsDir else { return nil }
            let hour = Calendar.current.component(.hour, from: Date())
            let url = dir.appendingPathComponent(SpeakingClockGenerator.soundName(for: hour, minute: 0))
            try? SpeakingClockGenerator.generateIfNeeded(hour: hour, minute: 0, to: url)
            return url
        }

        // Custom sound
        if let customSound = customSounds.first(where: { $0.id == soundID }) {
            return customSoundsDir.appendingPathComponent(customSound.fileName)
        }

        // Built-in sound from bundle
        return Bundle.main.url(forResource: soundID, withExtension: "caf")
    }
    
    func notificationSoundName(for soundID: String) -> String {
        if let customSound = customSounds.first(where: { $0.id == soundID }) {
            return customSound.fileName
        }
        return "\(soundID).caf"
    }
    
    func stageForNotifications(soundID: String) {
        guard let libSounds = libSoundsDir else { return }
        
        // Clear existing notification sounds
        if let files = try? FileManager.default.contentsOfDirectory(atPath: libSounds.path) {
            for file in files {
                try? FileManager.default.removeItem(at: libSounds.appendingPathComponent(file))
            }
        }
        
        // Copy the selected sound
        let soundName = notificationSoundName(for: soundID)
        let destURL = libSounds.appendingPathComponent(soundName)
        if let src = previewURL(for: soundID) {
            try? FileManager.default.copyItem(at: src, to: destURL)
        }
    }
    
    // MARK: - Localized Name
    
    func localizedName(for soundID: String) -> String {
        // Check if it's a custom sound
        if let customSound = customSounds.first(where: { $0.id == soundID }) {
            return customSound.name
        }
        
        // Built-in sounds use String Catalog - use soundID directly as key
        return String(localized: LocalizedStringResource(String.LocalizationValue(soundID), bundle: .main))
    }
    
    // MARK: - Custom Sound Import
    
    func importSound(from securedURL: URL) throws -> Sound {
        let accessed = securedURL.startAccessingSecurityScopedResource()
        defer { if accessed { securedURL.stopAccessingSecurityScopedResource() } }

        // Safety net: enforce limit
        guard customSounds.count < SoundStore.customSoundLimit else {
            throw NSError(domain: "SoundImportError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Collection Complete"
            ])
        }

        // Validate file format
        let allowedExtensions = ["caf", "wav", "aiff", "aif"]
        let fileExtension = securedURL.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            throw NSError(
                domain: "SoundImportError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(localized: LocalizedStringResource("supported_formats", bundle: .main))]
            )
        }
        
        // Validate file duration (≤ 30 seconds)
        let audioPlayer = try AVAudioPlayer(contentsOf: securedURL)
        guard audioPlayer.duration <= 30.0 else {
            throw NSError(
                domain: "SoundImportError", 
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(localized: LocalizedStringResource("supported_formats", bundle: .main))]
            )
        }
        
        // Use UUID-based filename to prevent collisions when importing files with the same name
        let uuid = UUID().uuidString
        let uniqueFileName = "custom_\(uuid).\(fileExtension)"
        let destination = customSoundsDir.appendingPathComponent(uniqueFileName)

        // Copy the file
        try FileManager.default.copyItem(at: securedURL, to: destination)

        let sound = Sound.customSound(
            id: "custom_\(uuid)",
            name: securedURL.deletingPathExtension().lastPathComponent,
            fileName: uniqueFileName
        )
        
        DispatchQueue.main.async {
            self.customSounds.append(sound)
            self.save()
        }
        
        return sound
    }
    
    func delete(_ sound: Sound) {
        // Remove file from documents
        try? FileManager.default.removeItem(at: customSoundsDir.appendingPathComponent(sound.fileName))
        
        // Remove from library sounds if present
        if let lib = libSoundsDir {
            try? FileManager.default.removeItem(at: lib.appendingPathComponent(sound.fileName))
        }
        
        // Remove from array
        customSounds.removeAll { $0.id == sound.id }
        
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(customSounds) {
            UserDefaults.standard.set(data, forKey: customSoundsKey)
        }
    }
    
    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: customSoundsKey),
            let sounds = try? JSONDecoder().decode([Sound].self, from: data)
        else { return }
        customSounds = sounds
    }
}
