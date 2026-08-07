# Evertalk

Privacy-first local voice-to-text for Mac. No cloud, no subscriptions, no telemetry.

Press **Cmd+Shift+Space**, speak, and text appears in your clipboard.

## Features

- **Global hotkey** - Cmd+Shift+Space from any app
- **Fully local** - Whisper AI runs on your Mac, nothing sent to cloud
- **Fast** - ~2 seconds to transcribe on Apple Silicon
- **Menu bar app** - Always ready, no window clutter

## Install

```bash
brew install --cask Ram902-bot/tap/evertalk
```

On first launch, grant Microphone permission when prompted.

## Usage

| Action | Shortcut |
|--------|----------|
| Start recording | **Cmd+Shift+Space** |
| Stop & transcribe | **Cmd+Shift+Space** |
| Paste result | **Cmd+V** |

The mic icon in your menu bar shows status:
- 🎙️ Ready
- 🎙️ (filled) Recording

## Privacy

- **Zero network calls** - all processing is local
- **No telemetry** - we don't track anything
- **No cloud** - your audio never leaves your Mac
- **Open source** - audit the code yourself

## Tech Stack

- **SwiftUI** - Native macOS app
- **WhisperKit** - Apple-optimized Whisper model
- **Whisper base.en** - ~140MB model, good accuracy

## Build from Source

```bash
git clone https://github.com/Ram902-bot/evertalk.git
cd evertalk
open Evertalk.xcodeproj
# Build (Cmd+B) and Run (Cmd+R)
```

Requires Xcode 15+ and macOS 14+.

## License

MIT License - see [LICENSE](LICENSE)

### Third-Party Licenses

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - MIT License
- [Whisper](https://github.com/openai/whisper) - MIT License

---

Built by [Everstage](https://everstage.com) team.
