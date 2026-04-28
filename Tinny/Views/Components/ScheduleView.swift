// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import SwiftUI
import Foundation

struct ScheduleView: View {
    // MARK: - Properties
    let selectedHours: Set<Int>
    let selectedInterval: Int
    let selectedDays: Set<Int>
    let presets: [(id: String, nameKey: String, startHour: Int, endHour: Int)]
    let intervalPresets: [(interval: Int, nameKey: String)]
    let dayPresets: [(id: String, nameKey: String, days: Set<Int>)]
    let isPremium: Bool
    let formatHourRange: (Int, Int) -> String
    let onSetHours: (Set<Int>) -> Void
    let onToggleHour: (Int) -> Void
    let onSetInterval: (Int) -> Void
    let onSetDays: (Set<Int>) -> Void
    let onShowPaywall: () -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("schedule", bundle: .main)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            hourPresetButtons
            hourGrid
            intervalRow
            dayRow
            activeHoursCount
        }
    }

    // MARK: - Hour Preset Buttons

    private var hourPresetButtons: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.id) { preset in
                Button {
                    withAnimation(.smooth(duration: 0.15)) {
                        if preset.id == "clear" {
                            onSetHours([])
                        } else {
                            onSetHours(Set(preset.startHour...preset.endHour))
                        }
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text(LocalizedStringKey(preset.nameKey), bundle: .main)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        if preset.id == "clear" {
                            Text("none", bundle: .main)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(formatHourRange(preset.startHour, preset.endHour))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(0..<24, id: \.self) { hour in
                let on = selectedHours.contains(hour)
                let isCurrent = hour == currentHour
                Button {
                    withAnimation(.smooth(duration: 0.1)) { onToggleHour(hour) }
                } label: {
                    Text(formatHour(hour))
                        .font(.system(.caption2, design: .rounded, weight: on ? .bold : .regular))
                        .foregroundStyle(on ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? Color.accentColor : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(
                                    on ? Color.white.opacity(0.6) : Color.accentColor.opacity(0.5),
                                    lineWidth: 1.5
                                )
                                .opacity(isCurrent ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Interval Row (Pro)

    private var intervalRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("interval_section", bundle: .main)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)

            HStack(spacing: 8) {
                ForEach(intervalPresets, id: \.interval) { preset in
                    let isSelected = selectedInterval == preset.interval
                    let requiresPremium = preset.interval != 1

                    Button {
                        if requiresPremium && !isPremium {
                            onShowPaywall()
                        } else {
                            withAnimation(.smooth(duration: 0.15)) {
                                onSetInterval(preset.interval)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(preset.nameKey), bundle: .main)
                                .font(.system(.caption, design: .rounded, weight: isSelected ? .semibold : .regular))
                            if requiresPremium && !isPremium {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Day Row (Pro)

    private var dayRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("days_section", bundle: .main)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)

            HStack(spacing: 8) {
                ForEach(dayPresets, id: \.id) { preset in
                    let isSelected = selectedDays == preset.days
                    let requiresPremium = preset.id != "everyday"

                    Button {
                        if requiresPremium && !isPremium {
                            onShowPaywall()
                        } else {
                            withAnimation(.smooth(duration: 0.15)) {
                                onSetDays(preset.days)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(preset.nameKey), bundle: .main)
                                .font(.system(.caption, design: .rounded, weight: isSelected ? .semibold : .regular))
                            if requiresPremium && !isPremium {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Active Hours Count

    private var activeHoursCount: some View {
        Text(String(format: String(localized: LocalizedStringResource("hours_active_format", bundle: .main)), selectedHours.count))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Hour Formatting

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        let is12Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?
            .contains("a") ?? false

        if is12Hour {
            formatter.setLocalizedDateFormatFromTemplate("ha")
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return formatter.string(from: date)
        } else {
            return String(format: "%02d", hour)
        }
    }
}

// MARK: - Preview

#Preview {
    ScheduleView(
        selectedHours: Set([9, 10, 11, 14, 15]),
        selectedInterval: 1,
        selectedDays: [],
        presets: [
            ("work",   "Work",    9, 17),
            ("waking", "Waking",  7, 21),
            ("allday", "All day", 0, 23),
            ("clear",  "Clear",   0,  0)
        ],
        intervalPresets: [
            (1,  "interval_hourly"),
            (30, "interval_30min"),
            (15, "interval_15min")
        ],
        dayPresets: [
            ("everyday", "days_every_day", []),
            ("weekdays", "days_weekdays",  [2, 3, 4, 5, 6]),
            ("weekends", "days_weekends",  [7, 1])
        ],
        isPremium: false,
        formatHourRange: { "\($0):00 – \($1):00" },
        onSetHours:    { _ in },
        onToggleHour:  { _ in },
        onSetInterval: { _ in },
        onSetDays:     { _ in },
        onShowPaywall: {}
    )
    .padding()
}
