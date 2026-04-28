// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Content View

struct ContentView: View {
    // MARK: - App Storage (stays in View per Apple guidelines)
    @AppStorage("chimeEnabled")       private var chimeEnabled       = false
    @AppStorage("selectedSound")      private var selectedSound      = "beeper"
    @AppStorage("selectedHoursData")  private var selectedHoursData  = Data()
    @AppStorage("selectedInterval")   private var selectedInterval   = 1
    @AppStorage("selectedDaysData")   private var selectedDaysData   = Data()

    // MARK: - ViewModel + PurchaseManager
    @State private var purchaseManager: PurchaseManager
    @State private var viewModel: ContentViewModel

    init() {
        let pm = PurchaseManager()
        let chimeEnabled    = UserDefaults.standard.bool(forKey: "chimeEnabled")
        let selectedSound   = UserDefaults.standard.string(forKey: "selectedSound") ?? "beeper"
        let hoursData       = UserDefaults.standard.data(forKey: "selectedHoursData") ?? Data()
        let hours           = (try? JSONDecoder().decode(Set<Int>.self, from: hoursData)) ?? Set(9...17)
        let interval        = UserDefaults.standard.integer(forKey: "selectedInterval").nonZero ?? 1
        let daysData        = UserDefaults.standard.data(forKey: "selectedDaysData") ?? Data()
        let days            = (try? JSONDecoder().decode(Set<Int>.self, from: daysData)) ?? []

        _purchaseManager = State(initialValue: pm)
        _viewModel = State(initialValue: ContentViewModel(
            chimeEnabled:     chimeEnabled,
            selectedSound:    selectedSound,
            selectedHours:    hours,
            selectedInterval: interval,
            selectedDays:     days,
            purchaseManager:  pm
        ))
    }

    // MARK: - Environment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        header
                        scheduleSection
                        soundSection
                        tipSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top)
                    .padding(.bottom, 40)
                }
                .background(Color(.systemBackground))
                .ignoresSafeArea(edges: .top)

                Color.clear
                    .frame(height: geometry.safeAreaInsets.top)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .onAppear { viewModel.startTimer() }
        .onDisappear { viewModel.stopTimer() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.refreshFlag.toggle()
            viewModel.rescheduleIfActive()  // top up the 64-notification window
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { viewModel.startTimer() } else { viewModel.stopTimer() }
        }
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { viewModel.handleImport($0) }
        .alert(
            String(localized: LocalizedStringResource("import_failed_title", bundle: .main)),
            isPresented: .init(
                get: { viewModel.importError != nil },
                set: { if !$0 { viewModel.importError = nil } }
            )
        ) {
            Button(String(localized: LocalizedStringResource("ok", bundle: .main))) { viewModel.importError = nil }
        } message: {
            Text(viewModel.importError ?? "")
        }
        .alert("Collection Complete", isPresented: $viewModel.showLimitAlert) {
            Button(String(localized: LocalizedStringResource("ok", bundle: .main))) { }
        } message: {
            Text("collection_complete_body", bundle: .main)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
        // Sync AppStorage
        .onChange(of: viewModel.chimeEnabled)      { _, v in chimeEnabled      = v }
        .onChange(of: viewModel.selectedSound)     { _, v in selectedSound     = v }
        .onChange(of: viewModel.selectedInterval)  { _, v in selectedInterval  = v }
        .onChange(of: viewModel.selectedHours)     { _, v in
            selectedHoursData = (try? JSONEncoder().encode(v)) ?? Data()
        }
        .onChange(of: viewModel.selectedDays)      { _, v in
            selectedDaysData  = (try? JSONEncoder().encode(v)) ?? Data()
        }
        .onChange(of: viewModel.isPremium) { _, newValue in
            if newValue { viewModel.showPaywall = false }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HeaderView(
            chimeEnabled:   viewModel.chimeEnabled,
            nextChimeText:  viewModel.nextChime,
            hasSelectedHours: !viewModel.selectedHours.isEmpty,
            isPremium:          viewModel.isPremium,
            onToggleChime:  { viewModel.toggleChime() }
        )
    }

    private var scheduleSection: some View {
        ScheduleView(
            selectedHours:    viewModel.selectedHours,
            selectedInterval: viewModel.selectedInterval,
            selectedDays:     viewModel.selectedDays,
            presets:          viewModel.presets,
            intervalPresets:  viewModel.intervalPresets,
            dayPresets:       viewModel.dayPresets,
            isPremium:            viewModel.isPremium,
            formatHourRange:  viewModel.formatHourRange,
            onSetHours:       { viewModel.setHours($0) },
            onToggleHour: { hour in
                var hours = viewModel.selectedHours
                if hours.contains(hour) { hours.remove(hour) } else { hours.insert(hour) }
                viewModel.setHours(hours)
            },
            onSetInterval:    { viewModel.setInterval($0) },
            onSetDays:        { viewModel.setDays($0) },
            onShowPaywall:    { viewModel.showPaywall = true }
        )
    }

    private var soundSection: some View {
        SoundSelectionView(
            allSoundIDs:   viewModel.allSoundIDs,
            selectedSound: viewModel.selectedSound,
            previewingID:  viewModel.previewingID,
            isPremium:         viewModel.isPremium,
            store:         viewModel.store,
            onSelectSound: { soundID in
                let isFree = SoundStore.freeSoundIDs.contains(soundID)
                if !viewModel.isPremium && !isFree {
                    viewModel.playPreview(id: soundID)
                    viewModel.showPaywall = true
                    return
                }
                if soundID == SoundStore.speakingClockID {
                    viewModel.invalidateSpeakingClockCache()
                }
                viewModel.selectedSound = soundID
                viewModel.rescheduleIfActive()
                viewModel.playPreview(id: soundID)
            },
            onDeleteCustom: { viewModel.deleteCustom(id: $0) },
            onImportSound: {
                if viewModel.isPremium {
                    if viewModel.store.customSounds.count >= SoundStore.customSoundLimit {
                        viewModel.showLimitAlert = true
                    } else {
                        viewModel.showFilePicker = true
                    }
                } else {
                    viewModel.showPaywall = true
                }
            }
        )
    }

    private var tipSection: some View {
        TipView()
    }
}

// MARK: - Helpers

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - Preview
#Preview {
    ContentView()
}
