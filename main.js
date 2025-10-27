import { app, BrowserWindow, ipcMain } from 'electron';
import path from 'path';
import { fileURLToPath } from 'url';
import os from 'os';
import fs from 'fs';
import { runWhisperCpp } from './backends/whispercpp.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let mainWindow;

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 560,
    webPreferences: {
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  await mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// Receive WAV buffer from renderer and transcribe via whisper.cpp
ipcMain.handle('transcribe-wav', async (event, { wavBuffer }) => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ld-'));
  const wavPath = path.join(tmpDir, 'rec.wav');
  fs.writeFileSync(wavPath, Buffer.from(wavBuffer));
  try {
    const transcript = await runWhisperCpp({
      audioPath: wavPath,
      modelPath: path.join(__dirname, 'models', 'ggml-base.en.bin'),
      binPath: path.join(__dirname, 'bin', process.platform === 'win32' ? 'whisper.exe' : 'whisper-cli')
    });
    return { ok: true, text: transcript };
  } catch (e) {
    return { ok: false, error: String(e) };
  } finally {
    try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  }
});
