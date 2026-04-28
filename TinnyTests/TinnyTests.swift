// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import Testing
@testable import Tinny

// MARK: - SpeakingClockGenerator.speechText

@Suite("Speaking Clock — speech text")
struct SpeakingClockTextTests {

    // Special cases
    @Test func midnight()    { #expect(SpeakingClockGenerator.speechText(for: 0,  minute: 0) == "Midnight") }
    @Test func noon()        { #expect(SpeakingClockGenerator.speechText(for: 12, minute: 0) == "Noon") }

    // AM hours on the hour
    @Test func oneAM()       { #expect(SpeakingClockGenerator.speechText(for: 1,  minute: 0) == "One A M") }
    @Test func sixAM()       { #expect(SpeakingClockGenerator.speechText(for: 6,  minute: 0) == "Six A M") }
    @Test func elevenAM()    { #expect(SpeakingClockGenerator.speechText(for: 11, minute: 0) == "Eleven A M") }

    // PM hours on the hour (13 → 1 PM, 23 → 11 PM)
    @Test func onePM()       { #expect(SpeakingClockGenerator.speechText(for: 13, minute: 0) == "One P M") }
    @Test func sixPM()       { #expect(SpeakingClockGenerator.speechText(for: 18, minute: 0) == "Six P M") }
    @Test func elevenPM()    { #expect(SpeakingClockGenerator.speechText(for: 23, minute: 0) == "Eleven P M") }

    // Sub-hourly minutes
    @Test func oneThirtyAM() { #expect(SpeakingClockGenerator.speechText(for: 1,  minute: 30) == "One thirty A M") }
    @Test func threeFifteen() { #expect(SpeakingClockGenerator.speechText(for: 3, minute: 15) == "Three fifteen A M") }
    @Test func nineFortyFivePM() { #expect(SpeakingClockGenerator.speechText(for: 21, minute: 45) == "Nine forty-five P M") }
    @Test func twelveFifteenPM() { #expect(SpeakingClockGenerator.speechText(for: 12, minute: 15) == "Twelve fifteen P M") }

    // Midnight with minutes (edge case: hour 0 with non-zero minute)
    @Test func midnightThirty() { #expect(SpeakingClockGenerator.speechText(for: 0, minute: 30) == "Twelve thirty A M") }
}

// MARK: - NotificationManager.minutesForInterval

@Suite("Notification — minutes for interval")
struct MinutesForIntervalTests {

    @Test func hourly()        { #expect(NotificationManager.minutesForInterval(1)  == [0]) }
    @Test func thirtyMin()     { #expect(NotificationManager.minutesForInterval(30) == [0, 30]) }
    @Test func fifteenMin()    { #expect(NotificationManager.minutesForInterval(15) == [0, 15, 30, 45]) }

    @Test func hourlyCount()   { #expect(NotificationManager.minutesForInterval(1).count  == 1) }
    @Test func thirtyCount()   { #expect(NotificationManager.minutesForInterval(30).count == 2) }
    @Test func fifteenCount()  { #expect(NotificationManager.minutesForInterval(15).count == 4) }

    @Test func alwaysStartsAtZero() {
        for interval in [1, 15, 30] {
            #expect(NotificationManager.minutesForInterval(interval).first == 0)
        }
    }
}
