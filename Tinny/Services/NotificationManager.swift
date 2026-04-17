// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import UserNotifications

enum NotificationManager {

    static func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    /// Schedule chime notifications.
    /// - Parameters:
    ///   - hours: Hour numbers (0-23) to chime on.
    ///   - days: Calendar weekday numbers (1=Sun … 7=Sat). Empty means every day.
    ///   - interval: Minute interval within each hour (1 = on the hour only, 15 or 30 for sub-hourly).
    ///   - soundID: The selected sound identifier.
    ///   - store: Sound store for file staging.
    static func schedule(
        hours: Set<Int>,
        days: Set<Int>,
        interval: Int,
        soundID: String,
        store: SoundStore
    ) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !hours.isEmpty else { return }

        // Stage audio files in background, then schedule notifications
        DispatchQueue.global(qos: .utility).async {
            if soundID == SoundStore.speakingClockID {
                stageSpeakingClockFiles(hours: hours, interval: interval, store: store)
            } else {
                store.stageForNotifications(soundID: soundID)
            }
        }

        let minutes = minutesForInterval(interval)
        let activeDays: Set<Int> = days.isEmpty ? [] : days  // empty = all days (no weekday filter)

        // Build all (weekday?, hour, minute) combinations, sorted by next occurrence, capped at 64
        let combinations = buildSchedule(hours: hours, days: activeDays, minutes: minutes)

        let title = String(localized: LocalizedStringResource("notification_title", bundle: .main))
        let bodyFormat = String(localized: LocalizedStringResource("notification_body_format", bundle: .main))

        for combo in combinations {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = String(format: bodyFormat, formatTimeForNotification(hour: combo.hour, minute: combo.minute))

            if soundID == SoundStore.speakingClockID {
                let name = UNNotificationSoundName(rawValue: SpeakingClockGenerator.soundName(for: combo.hour, minute: combo.minute))
                content.sound = UNNotificationSound(named: name)
            } else {
                let name = UNNotificationSoundName(rawValue: store.notificationSoundName(for: soundID))
                content.sound = UNNotificationSound(named: name)
            }

            var dc = DateComponents()
            dc.hour   = combo.hour
            dc.minute = combo.minute
            dc.second = 0
            if let wd = combo.weekday { dc.weekday = wd }

            let identifier: String
            if let wd = combo.weekday {
                identifier = "chime_\(wd)_\(combo.hour)_\(combo.minute)"
            } else {
                identifier = "chime_\(combo.hour)_\(combo.minute)"
            }

            center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            ))
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Schedule Building

    private struct Combo {
        let weekday: Int?
        let hour: Int
        let minute: Int
    }

    private static func buildSchedule(hours: Set<Int>, days: Set<Int>, minutes: [Int]) -> [Combo] {
        var combos: [Combo] = []

        if days.isEmpty {
            for hour in hours {
                for minute in minutes {
                    combos.append(Combo(weekday: nil, hour: hour, minute: minute))
                }
            }
        } else {
            for day in days {
                for hour in hours {
                    for minute in minutes {
                        combos.append(Combo(weekday: day, hour: hour, minute: minute))
                    }
                }
            }
        }

        // Sort by next occurrence, cap at 64 (iOS notification limit)
        let now = Date()
        let sorted = combos.sorted { a, b in
            nextOccurrence(of: a, after: now) < nextOccurrence(of: b, after: now)
        }
        return Array(sorted.prefix(64))
    }

    private static func nextOccurrence(of combo: Combo, after date: Date) -> Date {
        var dc = DateComponents()
        dc.hour   = combo.hour
        dc.minute = combo.minute
        dc.second = 0
        if let wd = combo.weekday { dc.weekday = wd }
        return Calendar.current.nextDate(after: date, matching: dc, matchingPolicy: .nextTime)
            ?? .distantFuture
    }

    // MARK: - Speaking Clock Staging

    private static func stageSpeakingClockFiles(hours: Set<Int>, interval: Int, store: SoundStore) {
        guard let libDir = store.libSoundsDir else { return }

        // Remove non-speaking-clock files
        if let files = try? FileManager.default.contentsOfDirectory(atPath: libDir.path) {
            for file in files where !file.hasPrefix("speakingclock_") {
                try? FileManager.default.removeItem(at: libDir.appendingPathComponent(file))
            }
        }

        // Generate needed TTS files
        let minutes = minutesForInterval(interval)
        for hour in hours {
            for minute in minutes {
                let url = libDir.appendingPathComponent(SpeakingClockGenerator.soundName(for: hour, minute: minute))
                try? SpeakingClockGenerator.generateIfNeeded(hour: hour, minute: minute, to: url)
            }
        }
    }

    // MARK: - Helpers

    static func minutesForInterval(_ interval: Int) -> [Int] {
        guard interval > 1 else { return [0] }
        return Array(stride(from: 0, to: 60, by: interval))
    }

    private static func formatTimeForNotification(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        let is12Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?
            .contains("a") ?? false

        if is12Hour {
            formatter.setLocalizedDateFormatFromTemplate(minute == 0 ? "ha" : "h:mm a")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        }

        let calendar = Calendar.current
        let now = Date()
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return formatter.string(from: date)
    }
}
