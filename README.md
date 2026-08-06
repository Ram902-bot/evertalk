# Evertalk

Privacy-first local voice-to-text for Mac. No cloud, no subscriptions, no telemetry.

Press **Cmd+Shift+Space**, speak, and text appears in your clipboard.

## Features

- **Global hotkey** - Cmd+Shift+Space from any app
- **Fully local** - Whisper AI runs on your Mac, nothing sent to cloud
- **Fast** - ~2 seconds to transcribe on Apple Silicon
- **Menu bar app** - Always ready, no window clutter

## Install

### Download the app

1. Download `Evertalk.app` from [Releases](https://github.com/everstage/evertalk/releases)
2. Drag to Applications
3. Open Evertalk
4. Grant Microphone permission when prompted

### Build from source

```bash
# Clone
git clone https://github.com/everstage/evertalk.git
cd evertalk

# Open in Xcode
open Evertalk.xcodeproj

# Build (Cmd+B) and Run (Cmd+R)
```

Requires Xcode 15+ and macOS 14+.

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

## CLI Version

A lightweight CLI version is also available:

```bash
# Install dependencies
brew install sox whisper-cpp

# Run
./evertalk.sh
```

See `evertalk.sh` for details.

## License

MIT License - see [LICENSE](LICENSE)

### Third-Party Licenses

This project uses:
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - MIT License
- [Whisper](https://github.com/openai/whisper) - MIT License

---

Built by [Everstage](https://everstage.com) team.
