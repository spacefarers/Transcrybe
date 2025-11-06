<div align="center">
  <img src="Transcryb.png" alt="Dropp Logo" width="120" height="120">
  <h1>Transcryb</h1>
  <p><strong>Fully Local Push-to-Transcribe</strong></p>
  <p>Lightweight voice transcription app that works entirely offline. Press the Function key to record, and get instant transcriptions. All processed locally on your machine. No Cloud, no Tracking, no Subscription.</p>

  <p>
    <a href="https://github.com/spacefarers/Transcryb/releases/download/v1.1/Transcryb-macOS.dmg">
      <img src="https://img.shields.io/badge/Download-macOS-blue?style=for-the-badge" alt="Download macOS">
    </a>
    <a href="https://github.com/spacefarers/Transcryb/releases/download/v1.1/Transcryb-win64.msi">
      <img src="https://img.shields.io/badge/Download-Windows-0078d4?style=for-the-badge" alt="Download Windows">
    </a>
  </p>
</div>

## Key Features

- **100% Local** – All transcription happens on your device. Your voice data never touches the internet
- **One-Key Recording** – Press the Function key to start/stop recording from anywhere
- **Instant Results** – Get transcriptions in less than 1 second
- **Completely Free and Open Source** – No monthly quotas, no subscription, just FOSS.
- **Simple & Fast** – Lightweight, minimal UI, maximum efficiency

---

## Demo

![Demo](Demo.gif)

---

## Platform Support

- **macOS** 14.6+ (Sonoma onwards) – Press **Function key** to record
- **Windows** – Press **Control + Windows key** to record
- Model file needs to be constantly stored in memory for fast transcription (40MB, 140MB, or 440MB depending on the model you choose)
- Microphone access required

---

## Quick Start

1. Download and install Transcryb (if permission requests perform unexpectedly, try quitting and restarting)
2. Grant microphone and accessibility permissions when prompted
3. Select an input field and press your platform's hotkey to start recording:
   - **macOS**: Function key
   - **Windows**: Control + Windows key
4. Release to stop recording
5. Done! Your transcription will appear in the selected input field

---

## Credits

Transcryb is powered by [**whisper.cpp**](https://github.com/ggerganov/whisper.cpp) – an amazing C++ implementation of OpenAI's Whisper that makes offline transcription blazingly fast. Big thanks to the whisper.cpp team for building such incredible infrastructure that made this project possible! 🙏
