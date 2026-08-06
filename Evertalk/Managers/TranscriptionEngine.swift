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
            // Load model from app bundle Resources folder (no download needed)
            // Model files (AudioEncoder.mlmodelc, TextDecoder.mlmodelc, etc.) are at Resources root
            guard let resourcePath = Bundle.main.resourcePath,
                  FileManager.default.fileExists(atPath: resourcePath + "/AudioEncoder.mlmodelc") else {
                print("Model not found in bundle - falling back to download")
                whisperKit = try await WhisperKit(
                    model: "small.en",
                    verbose: false,
                    logLevel: .none
                )
                isLoading = false
                return
            }

            whisperKit = try await WhisperKit(
                modelFolder: resourcePath,
                verbose: false,
                logLevel: .none
            )
            print("WhisperKit model loaded from bundle successfully")
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

        // Remove common hallucinations (Whisper trained on YouTube)
        let hallucinations = [
            "thank you for watching",
            "thanks for watching",
            "please subscribe",
            "like and subscribe",
            "subtitles by the amara.org community",
            "subtitles by the amara org community",
            "satsang with mooji",
            "transcribed by https://otter.ai",
            "www.mooji.org"
        ]

        let lowerText = text.lowercased()
        for hallucination in hallucinations {
            if lowerText == hallucination || lowerText.hasPrefix(hallucination + ".") || lowerText.hasPrefix(hallucination + "!") {
                return ""
            }
        }

        // Fix common homophones
        text = fixHomophones(text)

        return text
    }

    private func fixHomophones(_ text: String) -> String {
        var result = text

        // "High" at start of sentence or after punctuation → "Hi"
        // Matches: "High," "High!" "High." or "High " at start
        let patterns: [(pattern: String, replacement: String)] = [
            ("^High,", "Hi,"),
            ("^High!", "Hi!"),
            ("^High\\.", "Hi."),
            ("^High ", "Hi "),
            ("\\. High,", ". Hi,"),
            ("\\. High ", ". Hi "),
            ("! High,", "! Hi,"),
            ("! High ", "! Hi "),
            ("\\? High,", "? Hi,"),
            ("\\? High ", "? Hi ")
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        return result
    }
}
