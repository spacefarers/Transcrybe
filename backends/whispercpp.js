import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

export async function runWhisperCpp({ audioPath, modelPath, binPath }){
  await ensureExists(modelPath, 'Model file not found');
  await ensureExists(binPath, 'whisper.cpp binary not found');

  const outBase = path.join(path.dirname(audioPath), 'out');
  const args = [
    '-m', modelPath,
    '-f', audioPath,
    '-l', 'en',
    '-otxt',
    '-of', outBase,
    '-pc',            // disable color codes when unsupported
    '-bs', '5'        // beam size similar to the Python app
  ];

  const proc = spawn(binPath, args, { stdio: ['ignore', 'pipe', 'pipe'] });

  let stderr = '';
  proc.stderr.on('data', d => { stderr += d.toString(); });

  await new Promise((resolve, reject) => {
    proc.on('error', reject);
    proc.on('close', code => code === 0 ? resolve() : reject(new Error(`whisper.cpp exit ${code}: ${stderr}`)));
  });

  const txtPath = outBase + '.txt';
  const text = fs.readFileSync(txtPath, 'utf8');
  return text.trim();
}

function ensureExists(p, msg){
  return new Promise((resolve, reject) => fs.access(p, fs.constants.F_OK, err => err ? reject(new Error(msg + ` at ${p}`)) : resolve()));
}
