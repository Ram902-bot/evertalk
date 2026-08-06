import Foundation
import WhisperKit

enum TranscriptionError: Error {
    case modelNotLoaded
    case transcriptionFailed(String)
}

class TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private var isLoading = false

    init() {
        Task {
            await loadModel()
        }
    }

    private func loadModel() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            // WhisperKit will download the model if not cached
            whisperKit = try await WhisperKit(
                model: "base.en",
                verbose: false,
                logLevel: .none
            )
            print("WhisperKit model loaded successfully")
        } catch {
            print("Failed to load WhisperKit model: \(error)")
        }

        isLoading = false
    }

    func transcribe(audioBuffer: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            // Try loading model if not ready
            await loadModel()

            guard let whisperKit = self.whisperKit else {
                throw TranscriptionError.modelNotLoaded
            }

            return try await performTranscription(whisperKit: whisperKit, audioBuffer: audioBuffer)
        }

        return try await performTranscription(whisperKit: whisperKit, audioBuffer: audioBuffer)
    }

    private func performTranscription(whisperKit: WhisperKit, audioBuffer: [Float]) async throws -> String {
        let results = try await whisperKit.transcribe(audioArray: audioBuffer)

        guard let result = results.first else {
            throw TranscriptionError.transcriptionFailed("No transcription result")
        }

        // Clean up the text
        var text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common Whisper artifacts
        let artifacts = [
            "[BLANK_AUDIO]",
            "[BLANK AUDIO]",
            "(silence)",
            "[ Pause ]",
            "[Pause]",
            "(pause)",
            "[Music]",
            "[MUSIC]",
            "(music)",
            "[Applause]",
            "[APPLAUSE]",
            "(applause)",
            "[Laughter]",
            "[LAUGHTER]",
            "(laughter)",
            "...",
            "[ Silence ]",
            "[Silence]"
        ]

        for artifact in artifacts {
            text = text.replacingOccurrences(of: artifact, with: "", options: .caseInsensitive)
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // If only artifacts were detected, return empty
        if text.isEmpty {
            return ""
        }

        return text
    }
}
