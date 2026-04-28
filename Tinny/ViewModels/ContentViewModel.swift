// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import Foundation
import SwiftUI
import AVFoundation

@Observable
final class ContentViewModel {
    // MARK: - Persisted Properties (no @AppStorage here!)
    var chimeEnabled: Bool
    var selectedSound: String
    var selectedHours: Set<Int>
    var selectedInterval: Int      // 1 = hourly, 15 = every 15 min, 30 = every 30 min
    var selectedDays: Set<Int>     // Calendar weekday numbers (1=Sun…7=Sat), empty = every day

    // MARK: - Dependencies
    let store: SoundStore
    private let notificationManager: NotificationManager.Type
    let purchaseManager: PurchaseManager

    // MARK: - UI State
    var previewPlayer: AVAudioPlayer?
    var previewingID: String?
    var showFilePicker = false
    var importError: String?
    var showLimitAlert = false
    var refreshFlag = false
    var timer: Timer?
    var showPaywall = false

    // MARK: - Pro status
    var isPremium: Bool { purchaseManager.isPremium }

    // MARK: - Computed Properties

    var nextChime: String {
        guard !selectedHours.isEmpty else {
            return String(localized: LocalizedStringResource("no_hours_selected", bundle: .main))
        }

        let minutes = NotificationManager.minutesForInterval(selectedInterval)
        let now = Date()
        var earliest: Date = .distantFuture

        let activeDays: Set<Int> = selectedDays.isEmpty ? Set(1...7) : selectedDays

        for hour in selectedHours {
            for minute in minutes {
                for weekday in activeDays {
                    var dc = DateComponents()
                    dc.hour    = hour
                    dc.minute  = minute
                    dc.second  = 0
                    dc.weekday = weekday
                    if let d = Calendar.current.nextDate(after: now, matching: dc, matchingPolicy: .nextTime),
                       d < earliest {
                        earliest = d
                    }
                }
            }
        }

        guard earliest != .distantFuture else {
            return String(localized: LocalizedStringResource("no_hours_selected", bundle: .main))
        }

        let formatted = formatDateTime(earliest)
        let formatString = String(localized: LocalizedStringResource("next_chime_format", bundle: .main))
        return String(format: formatString, formatted)
    }

    var allSoundIDs: [String] {
        (SoundStore.builtInSounds + store.customSounds.map(\.id))
            .sorted { lhs, rhs in
                let lhsFree = SoundStore.freeSoundIDs.contains(lhs)
                let rhsFree = SoundStore.freeSoundIDs.contains(rhs)
                if lhsFree != rhsFree { return lhsFree }
                return store.localizedName(for: lhs).localizedStandardCompare(
                    store.localizedName(for: rhs)
                ) == .orderedAscending
            }
    }

    // MARK: - Hour Presets
    let presets: [(id: String, nameKey: String, startHour: Int, endHour: Int)] = [
        ("work",   "Work",    9,  17),
        ("waking", "Waking",  7,  21),
        ("allday", "All day", 0,  23),
        ("clear",  "Clear",   0,   0)
    ]

    // MARK: - Interval Presets (Pro)
    let intervalPresets: [(interval: Int, nameKey: String)] = [
        (1,  "interval_hourly"),
        (30, "interval_30min"),
        (15, "interval_15min")
    ]

    // MARK: - Day Presets (Pro)
    // Calendar weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    let dayPresets: [(id: String, nameKey: String, days: Set<Int>)] = [
        ("everyday", "days_every_day", []),
        ("weekdays", "days_weekdays",  [2, 3, 4, 5, 6]),
        ("weekends", "days_weekends",  [7, 1])
    ]

    // MARK: - Initialization
    init(
        chimeEnabled: Bool = false,
        selectedSound: String = "beeper",
        selectedHours: Set<Int> = Set(9...17),
        selectedInterval: Int = 1,
        selectedDays: Set<Int> = [],
        store: SoundStore = .shared,
        notificationManager: NotificationManager.Type = NotificationManager.self,
        purchaseManager: PurchaseManager
    ) {
        self.chimeEnabled = chimeEnabled
        self.selectedSound = selectedSound
        self.selectedHours = selectedHours
        self.selectedInterval = selectedInterval
        self.selectedDays = selectedDays
        self.store = store
        self.notificationManager = notificationManager
        self.purchaseManager = purchaseManager
    }

    // MARK: - Timer Management

    func startTimer() {
        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshFlag.toggle()
        }
        RunLoop.current.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Schedule Management

    func setHours(_ hours: Set<Int>) {
        selectedHours = hours
        rescheduleIfActive()
    }

    func setInterval(_ interval: Int) {
        selectedInterval = interval
        rescheduleIfActive()
    }

    func setDays(_ days: Set<Int>) {
        selectedDays = days
        rescheduleIfActive()
    }

    /// Deletes all cached speaking clock CAF files so they regenerate
    /// with the current system voice next time the sound is scheduled/previewed.
    func invalidateSpeakingClockCache() {
        guard let libDir = store.libSoundsDir else { return }
        DispatchQueue.global(qos: .utility).async {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: libDir.path) {
                for file in files where file.hasPrefix("speakingclock_") {
                    try? FileManager.default.removeItem(at: libDir.appendingPathComponent(file))
                }
            }
        }
    }

    func toggleChime() {
        if chimeEnabled {
            chimeEnabled = false
            notificationManager.cancelAll()
        } else {
            notificationManager.requestPermission { [weak self] granted in
                if granted {
                    self?.chimeEnabled = true
                    self?.rescheduleIfActive()
                }
            }
        }
    }

    func rescheduleIfActive() {
        guard chimeEnabled else { return }
        notificationManager.schedule(
            hours: selectedHours,
            days: selectedDays,
            interval: selectedInterval,
            soundID: selectedSound,
            store: store
        )
    }

    // MARK: - Sound Preview

    func playPreview(id: String) {
        if id == SoundStore.speakingClockID {
            playSpeakingClockPreview()
            return
        }

        guard let url = store.previewURL(for: id) else { return }

        previewPlayer?.stop()
        previewPlayer = nil
        previewingID = id

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()

            guard previewingID == id else { return }

            previewPlayer = player
            player.play()

            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.2) { [weak self] in
                guard self?.previewingID == id else { return }
                self?.previewingID = nil
                self?.previewPlayer = nil
                DispatchQueue.global(qos: .userInitiated).async {
                    try? AVAudioSession.sharedInstance().setActive(false)
                }
            }
        } catch {
            previewingID = nil
        }
    }

    private func playSpeakingClockPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewingID = SoundStore.speakingClockID

        let hour = Calendar.current.component(.hour, from: Date())

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = self?.store.previewURL(for: SoundStore.speakingClockID) else {
                DispatchQueue.main.async { self?.previewingID = nil }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.previewingID == SoundStore.speakingClockID else { return }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)

                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()

                    guard self.previewingID == SoundStore.speakingClockID else { return }
                    self.previewPlayer = player
                    player.play()

                    let id = SoundStore.speakingClockID
                    DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.2) { [weak self] in
                        guard self?.previewingID == id else { return }
                        self?.previewingID = nil
                        self?.previewPlayer = nil
                        DispatchQueue.global(qos: .userInitiated).async {
                            try? AVAudioSession.sharedInstance().setActive(false)
                        }
                    }
                } catch {
                    self.previewingID = nil
                }
            }
            _ = hour
        }
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewingID = nil
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    // MARK: - Sound Import

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            importError = e.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    guard let sound = try self?.store.importSound(from: url) else { return }
                    DispatchQueue.main.async {
                        self?.selectedSound = sound.id
                        self?.rescheduleIfActive()
                    }
                } catch {
                    DispatchQueue.main.async { self?.importError = error.localizedDescription }
                }
            }
        }
    }

    func deleteCustom(id: String) {
        guard let sound = store.customSounds.first(where: { $0.id == id }) else { return }
        if selectedSound == id { selectedSound = "beeper" }

        if previewingID == id { stopPreview() }

        store.delete(sound)
        rescheduleIfActive()
    }

    // MARK: - Formatting

    func formatHourRange(start: Int, end: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        let is12Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?
            .contains("a") ?? false

        formatter.setLocalizedDateFormatFromTemplate(is12Hour ? "ha" : "HH:mm")

        let calendar = Calendar.current
        let now = Date()
        let startStr = formatter.string(from: calendar.date(bySettingHour: start, minute: 0, second: 0, of: now) ?? now)
        let endStr   = formatter.string(from: calendar.date(bySettingHour: end,   minute: 0, second: 0, of: now) ?? now)
        return "\(startStr) – \(endStr)"
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        let is12Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?
            .contains("a") ?? false

        let cal = Calendar.current
        let minute = cal.component(.minute, from: date)
        if is12Hour {
            formatter.setLocalizedDateFormatFromTemplate(minute == 0 ? "ha" : "h:mm a")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        }

        return formatter.string(from: date)
    }
}
