#!/bin/bash

# Evertalk - Privacy-first local dictation
# No network calls. Fully local. Auditable.
# https://github.com/Ram902-bot/evertalk

set -e

# Config
MODEL_PATH="${EVERTALK_MODEL:-$HOME/.evertalk/models/ggml-base.en.bin}"
TEMP_DIR=$(mktemp -d)
AUDIO_FILE="$TEMP_DIR/recording.wav"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Cleanup on exit or interrupt
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT INT TERM

# Check dependencies
check_deps() {
    if ! command -v sox &> /dev/null; then
        echo -e "${RED}Error: sox not installed. Run: brew install sox${NC}"
        exit 1
    fi
    if ! command -v whisper-cli &> /dev/null; then
        echo -e "${RED}Error: whisper-cli not installed. Run: brew install whisper-cpp${NC}"
        exit 1
    fi
    if [ ! -f "$MODEL_PATH" ]; then
        echo -e "${RED}Error: Model not found at $MODEL_PATH${NC}"
        echo -e "Run: ${YELLOW}evertalk --download-model${NC}"
        exit 1
    fi
}

# Download model
download_model() {
    mkdir -p "$HOME/.evertalk/models"
    echo -e "${BLUE}Downloading base.en model (~140MB)...${NC}"
    curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" \
        -o "$HOME/.evertalk/models/ggml-base.en.bin"
    echo -e "${GREEN}Model downloaded to ~/.evertalk/models/ggml-base.en.bin${NC}"
    exit 0
}

# Record audio
record() {
    echo -e "${BLUE}Recording... Press Enter to stop.${NC}"
    # Run sox in background, capture PID
    sox -d -r 16000 -c 1 -b 16 "$AUDIO_FILE" 2>/dev/null &
    SOX_PID=$!

    # Wait for Enter key
    read -r

    # Stop recording
    kill $SOX_PID 2>/dev/null || true
    wait $SOX_PID 2>/dev/null || true

    echo -e "${GREEN}Recording stopped.${NC}"
}

# Transcribe
transcribe() {
    echo -e "${BLUE}Transcribing...${NC}" >&2
    # Run whisper-cli and extract just the text (skip timestamps)
    RESULT=$(whisper-cli -m "$MODEL_PATH" --no-prints --no-timestamps "$AUDIO_FILE" 2>/dev/null | grep -v "^$" | sed 's/^[[:space:]]*//')
    echo "$RESULT"
}

# Copy to clipboard
copy_to_clipboard() {
    echo -n "$1" | pbcopy
    echo -e "${GREEN}Copied to clipboard.${NC}"
}

# Auto-paste
auto_paste() {
    sleep 0.3
    osascript -e 'tell application "System Events" to keystroke "v" using command down'
    echo -e "${GREEN}Pasted.${NC}"
}

# Show help
show_help() {
    echo "Evertalk - Privacy-first local voice-to-text"
    echo ""
    echo "Usage: evertalk [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --paste           Auto-paste after transcription"
    echo "  --download-model  Download the Whisper model (~140MB)"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "How it works:"
    echo "  1. Run 'evertalk'"
    echo "  2. Speak"
    echo "  3. Press Enter to stop"
    echo "  4. Text is copied to clipboard"
    echo ""
    echo "Privacy: All processing happens locally. No network calls."
}

# Main
main() {
    case "${1:-}" in
        --download-model)
            download_model
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
    esac

    check_deps
    record

    if [ ! -s "$AUDIO_FILE" ]; then
        echo -e "${RED}No audio recorded.${NC}"
        exit 1
    fi

    RESULT=$(transcribe)

    if [ -n "$RESULT" ]; then
        echo -e "\n${YELLOW}Transcription:${NC}"
        echo "$RESULT"
        echo ""
        copy_to_clipboard "$RESULT"

        if [ "${1:-}" = "--paste" ]; then
            auto_paste
        fi
    else
        echo -e "${RED}No speech detected.${NC}"
    fi
}

main "$@"
