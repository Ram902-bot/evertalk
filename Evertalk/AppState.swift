import SwiftUI
import Combine

enum RecordingStatus {
    case settingUp
    case idle
    case recording
    case transcribing
}

@MainActor
class AppState: ObservableObject {
    @Published var status: RecordingStatus = .settingUp
    @Published var transcription: String = ""
    @Published var errorMessage: String?
    @Published var showOverlay: Bool = true  // Show during setup

    // Settings
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("playSounds") var playSounds: Bool = true

    let audioEngine = AudioEngine()
    let transcriptionEngine = TranscriptionEngine()
    let pasteManager = PasteManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe model ready state
        transcriptionEngine.$isModelReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                if isReady {
                    self?.status = .idle
                    // Hide overlay after setup complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.showOverlay = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    func toggleRecording() {
        switch status {
        case .settingUp:
            // Ignore while setting up
            break
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            // Ignore while transcribing
            break
        }
    }

    func startRecording() {
        // Save the current frontmost app so we can paste back to it
        pasteManager.saveFrontmostApp()

        do {
            try audioEngine.startRecording()
            status = .recording
            showOverlay = true

            if playSounds {
                NSSound(named: "Tink")?.play()
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        guard status == .recording else { return }

        status = .transcribing

        if playSounds {
            NSSound(named: "Pop")?.play()
        }

        Task {
            do {
                let audioBuffer = try await audioEngine.stopRecording()
                let text = try await transcriptionEngine.transcribe(audioBuffer: audioBuffer)

                transcription = text

                // Paste text inline (copies to clipboard and pastes)
                pasteManager.pasteText(text)

                status = .idle

                // Hide overlay after brief delay
                try? await Task.sleep(nanoseconds: 500_000_000)
                showOverlay = false

            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                status = .idle
                showOverlay = false
            }
        }
    }

}
