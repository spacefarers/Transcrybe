import sys, json
from faster_whisper import WhisperModel

# Simple one-shot transcriber: python faster_whisper.py /path/to/rec.wav

model = WhisperModel("base.en", device="cpu", compute_type="int8")

wav_path = sys.argv[1]
segments, info = model.transcribe(wav_path, beam_size=5)
text = " ".join([seg.text for seg in segments]).strip()
print(text)
