// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import Foundation
import AVFoundation

enum SpeakingClockGenerator {

    // MARK: - Public Interface

    /// Returns the notification sound filename for a given hour/minute.
    static func soundName(for hour: Int, minute: Int) -> String {
        "speakingclock_\(hour)_\(minute).caf"
    }

    /// Generates a TTS file for `hour`/`minute` at `url` if it doesn't already exist.
    static func generateIfNeeded(hour: Int, minute: Int, to url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try generateFile(hour: hour, minute: minute, to: url)
    }

    // MARK: - Internal

    static func generateFile(hour: Int, minute: Int, to url: URL) throws {
        let text = speechText(for: hour, minute: minute)
        let utterance = AVSpeechUtterance(string: text)

        // voice = nil → iOS uses the system voice (Settings → Accessibility → Spoken Content)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.4

        let synthesizer = AVSpeechSynthesizer()
        var audioFile: AVAudioFile?
        var writeError: Error?
        var signaled = false
        let semaphore = DispatchSemaphore(value: 0)

        synthesizer.write(utterance) { buffer in
            guard !signaled else { return }
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                signaled = true
                semaphore.signal()
                return
            }
            if pcmBuffer.frameLength == 0 {
                signaled = true
                semaphore.signal()
                return
            }
            do {
                if audioFile == nil {
                    audioFile = try AVAudioFile(forWriting: url, settings: pcmBuffer.format.settings)
                }
                try audioFile?.write(from: pcmBuffer)
            } catch {
                writeError = error
                signaled = true
                semaphore.signal()
            }
        }

        semaphore.wait()
        if let error = writeError { throw error }
        _ = synthesizer  // keep alive
    }

    // MARK: - Speech Text

    static func speechText(for hour: Int, minute: Int) -> String {
        if hour == 0 && minute == 0 { return "Midnight" }
        if hour == 12 && minute == 0 { return "Noon" }

        let h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour < 12 ? "A M" : "P M"
        let hourName = numberName(h12)

        if minute == 0 {
            return "\(hourName) \(ampm)"
        }
        return "\(hourName) \(minuteText(minute)) \(ampm)"
    }

    // MARK: - Helpers

    private static func numberName(_ n: Int) -> String {
        switch n {
        case 1:  return "One"
        case 2:  return "Two"
        case 3:  return "Three"
        case 4:  return "Four"
        case 5:  return "Five"
        case 6:  return "Six"
        case 7:  return "Seven"
        case 8:  return "Eight"
        case 9:  return "Nine"
        case 10: return "Ten"
        case 11: return "Eleven"
        case 12: return "Twelve"
        default: return "\(n)"
        }
    }

    private static func minuteText(_ minute: Int) -> String {
        switch minute {
        case 15: return "fifteen"
        case 30: return "thirty"
        case 45: return "forty-five"
        default: return String(format: "%02d", minute)
        }
    }
}
