import Foundation
import WhisperKit

enum TranscriptionError: Error {
    case modelNotLoaded
    case transcriptionFailed(String)
    case modelDownloadFailed(String)
}

@MainActor
class TranscriptionEngine: ObservableObject {
    private var whisperKit: WhisperKit?
    private var isLoading = false

    @Published var isModelReady = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var setupStatus: String = ""

    init() {
        Task {
            await loadModel()
        }
    }

    private func loadModel() async {
        guard !isLoading else { return }
        isLoading = true
        isDownloading = true
        setupStatus = "Setting up Evertalk..."

        do {
            // Download model to Application Support (persists across app updates)
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let evertalkDir = appSupport.appendingPathComponent("Evertalk")
            let modelDir = evertalkDir.appendingPathComponent("models")

            // Create directory if needed
            try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            // Check if model already exists
            let modelPath = modelDir.appendingPathComponent("openai_whisper-small.en")
            let modelExists = FileManager.default.fileExists(atPath: modelPath.appendingPathComponent("AudioEncoder.mlmodelc").path)

            if modelExists {
                setupStatus = "Loading model..."
                downloadProgress = 1.0
                whisperKit = try await WhisperKit(
                    modelFolder: modelPath.path,
                    verbose: false,
                    logLevel: .none
                )
            } else {
                setupStatus = "Downloading AI model..."

                // WhisperKit downloads to its default location, we'll use that
                whisperKit = try await WhisperKit(
                    model: "small.en",
                    verbose: false,
                    logLevel: .none,
                    prewarm: true,
                    load: true,
                    download: true
                )

                downloadProgress = 1.0
            }

            setupStatus = "Ready!"
            isModelReady = true
            isDownloading = false
            print("WhisperKit model loaded successfully")

        } catch {
            setupStatus = "Setup failed"
            isDownloading = false
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
