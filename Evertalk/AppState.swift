import SwiftUI
import Combine

enum RecordingStatus {
    case settingUp
    case setupFailed
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
    @AppStorage("showOverlayEnabled") var showOverlayEnabled: Bool = true

    // Overlay position persistence
    @AppStorage("overlayPositionX") var overlayPositionX: Double = -1
    @AppStorage("overlayPositionY") var overlayPositionY: Double = -1

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

        // Surface setup failures so the UI leaves the spinner and offers a retry
        transcriptionEngine.$setupFailed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] failed in
                guard let self else { return }
                if failed {
                    self.status = .setupFailed
                    self.showOverlay = true
                } else if self.status == .setupFailed {
                    self.status = .settingUp
                }
            }
            .store(in: &cancellables)

        // Views observe AppState; forward engine changes (progress, status text) so they redraw
        transcriptionEngine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func retrySetup() {
        guard status == .setupFailed else { return }
        transcriptionEngine.retrySetup()
    }

    func toggleRecording() {
        switch status {
        case .settingUp:
            // Ignore while setting up
            break
        case .setupFailed:
            retrySetup()
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
