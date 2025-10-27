# Local Dictation

Minimal Electron app that records audio while you hold Space, saves a WAV locally, and transcribes via a local Whisper backend (no cloud calls). Two backend options are included: whisper.cpp (default) and a Python faster-whisper script.

## Setup
1. Install dependencies
   ```
   npm install
   ```
2. Place the whisper.cpp binary in `bin/` and a model file in `models/`.
   - Example model: `models/ggml-base.en.bin`
   - Example binaries: `bin/whisper` (macOS/Linux) or `bin/whisper.exe` (Windows)
3. Run the app
   ```
   npm run dev
   ```

## Building whisper.cpp
- Build from https://github.com/ggerganov/whisper.cpp locally and copy the resulting binary to `bin/`.
- Run a quick test to validate:
  ```
  ./bin/whisper -m models/ggml-base.en.bin -f some.wav -otxt -of out
  ```

## Notes
- Audio captures at 16 kHz mono, encoded to 16-bit PCM WAV in the renderer.
- All transcription occurs locally via the native binary or the provided Python process.
- Current UX mirrors the Python app: hold Space to record, release to transcribe, and appends the result to the text area.
