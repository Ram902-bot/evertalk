import AppKit
import Foundation

/// Checks the Homebrew tap for a newer Evertalk and upgrades through Homebrew.
/// Reads the cask file rather than the GitHub releases API: the API allows 60
/// unauthenticated requests per hour per IP, which a shared office egress IP exhausts.
@MainActor
class UpdateChecker: ObservableObject {
    enum UpdateState: Equatable {
        case idle
        case available(String)
        case updating
        case failed(String)
    }

    @Published var state: UpdateState = .idle

    private static let caskURL = URL(string: "https://raw.githubusercontent.com/Ram902-bot/homebrew-tap/main/Casks/evertalk.rb")!
    private static let releasesURL = URL(string: "https://github.com/Ram902-bot/evertalk/releases/latest")!
    private static let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    private static let checkInterval: TimeInterval = 6 * 60 * 60

    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init() {
        Task { await checkForUpdates() }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates()
            }
        }
    }

    func checkForUpdates() async {
        guard state != .updating else { return }
        do {
            var request = URLRequest(url: Self.caskURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue("Evertalk/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let cask = String(data: data, encoding: .utf8),
                  let latest = Self.parseVersion(fromCask: cask) else { return }

            if Self.isVersion(latest, newerThan: currentVersion) {
                print("Update available: \(currentVersion) -> \(latest)")
                state = .available(latest)
            } else if case .available = state {
                state = .idle
            }
        } catch {
            // Offline or blocked: stay quiet and try again on the next check
            print("Update check failed: \(error.localizedDescription)")
        }
    }

    /// Upgrade via Homebrew, then relaunch. Without Homebrew, open the releases page.
    func installUpdate() {
        guard let brew = Self.brewPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            NSWorkspace.shared.open(Self.releasesURL)
            return
        }

        state = .updating
        Task.detached {
            let result = Self.run(brew, ["update", "--quiet"])
            let upgrade = result.status == 0 ? Self.run(brew, ["upgrade", "--cask", "evertalk"]) : result
            await MainActor.run {
                if upgrade.status == 0 {
                    Self.relaunch()
                } else {
                    let lastLine = upgrade.output.split(separator: "\n").last.map(String.init) ?? "Homebrew exited with \(upgrade.status)"
                    self.state = .failed(lastLine)
                }
            }
        }
    }

    // MARK: - Helpers

    nonisolated private static func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        // Apps launched from Finder get a minimal PATH; Homebrew needs its own bin dirs
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private static func relaunch() {
        let appPath = Bundle.main.bundlePath
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait for this process to exit before reopening the upgraded app
        relauncher.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.5; done; open \"\(appPath)\""]
        try? relauncher.run()
        NSApplication.shared.terminate(nil)
    }

    static func parseVersion(fromCask cask: String) -> String? {
        for line in cask.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("version ") else { continue }
            let parts = trimmed.split(separator: "\"")
            if parts.count >= 2 { return String(parts[1]) }
        }
        return nil
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
