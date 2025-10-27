// Records audio while Space is held, encodes to 16kHz mono WAV, sends to main for transcription.

const statusEl = document.getElementById('status');
const outEl = document.getElementById('out');

let mediaStream;
let audioContext;
let workletNode;
let recording = false;
let chunks = []; // Float32 chunks

async function setup() {
  audioContext = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });
  await audioContext.audioWorklet.addModule(URL.createObjectURL(new Blob([
    `class CaptureProcessor extends AudioWorkletProcessor {
      constructor(){ super(); this.port.onmessage = ()=>{}; }
      process(inputs){
        const ch0 = inputs[0][0];
        if (ch0) this.port.postMessage(ch0);
        return true;
      }
    }
    registerProcessor('capture-processor', CaptureProcessor);
    `
  ], { type: 'application/javascript' })));

  mediaStream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, sampleRate: 16000 }, video: false });
  const src = audioContext.createMediaStreamSource(mediaStream);
  workletNode = new AudioWorkletNode(audioContext, 'capture-processor');
  workletNode.port.onmessage = (e) => { if (recording) chunks.push(new Float32Array(e.data)); };
  src.connect(workletNode);
  workletNode.connect(audioContext.destination); // keep graph alive, volume is negligible

  window.addEventListener('keydown', (e) => { if (e.code === 'Space' && !recording) startRec(); });
  window.addEventListener('keyup', (e) => { if (e.code === 'Space' && recording) stopRec(); });

  status('Ready');
}

function status(msg){ statusEl.textContent = msg; }

function startRec(){
  chunks = [];
  recording = true;
  status('Recording...');
}

async function stopRec(){
  recording = false;
  status('Processing...');
  const wav = encodeWav(flattenFloat32(chunks), 16000);
  const res = await window.api.transcribeWav(wav);
  if (res.ok) {
    outEl.value += res.text + "\n\n";
    status('Ready');
  } else {
    status('Error: ' + res.error);
  }
}

function flattenFloat32(arrays){
  let len = 0; arrays.forEach(a => len += a.length);
  const out = new Float32Array(len);
  let off = 0; for (const a of arrays){ out.set(a, off); off += a.length; }
  return out;
}

function encodeWav(float32Data, sampleRate) {
  // 16-bit PCM little endian WAV
  const buffer = new ArrayBuffer(44 + float32Data.length * 2);
  const view = new DataView(buffer);

  // RIFF header
  writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + float32Data.length * 2, true);
  writeString(view, 8, 'WAVE');
  writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, true); // PCM chunk size
  view.setUint16(20, 1, true);  // PCM format
  view.setUint16(22, 1, true);  // mono
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true); // byte rate
  view.setUint16(32, 2, true);  // block align
  view.setUint16(34, 16, true); // bits per sample
  writeString(view, 36, 'data');
  view.setUint32(40, float32Data.length * 2, true);

  // PCM samples
  let offset = 44;
  for (let i = 0; i < float32Data.length; i++) {
    let s = Math.max(-1, Math.min(1, float32Data[i]));
    view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
    offset += 2;
  }

  return buffer;
}

function writeString(view, offset, str){ for (let i=0;i<str.length;i++) view.setUint8(offset+i, str.charCodeAt(i)); }

setup().catch(err => status('Init error: ' + err.message));
