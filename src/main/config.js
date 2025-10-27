const { UiohookKey } = require('uiohook-napi');

const DEFAULT_HOTKEY = 'CTRL+SPACE';
const DEFAULT_API_URL = 'http://127.0.0.1:8080/v1/audio/transcriptions';

const KEY_ALIASES = {
  CTRL: 'Ctrl',
  CONTROL: 'Ctrl',
  CMD: 'Meta',
  COMMAND: 'Meta',
  META: 'Meta',
  SUPER: 'Meta',
  WINDOWS: 'Meta',
  OPTION: 'Alt',
  ALT: 'Alt',
  SHIFT: 'Shift',
  SPACE: 'Space',
  SPACEBAR: 'Space',
  ENTER: 'Enter',
  RETURN: 'Enter',
  TAB: 'Tab',
  ESC: 'Escape',
  ESCAPE: 'Escape',
  CAPSLOCK: 'CapsLock',
  BACKSPACE: 'Backspace',
  DELETE: 'Delete',
  DEL: 'Delete',
  HOME: 'Home',
  END: 'End',
  PAGEUP: 'PageUp',
  PAGEDOWN: 'PageDown',
  UP: 'ArrowUp',
  DOWN: 'ArrowDown',
  LEFT: 'ArrowLeft',
  RIGHT: 'ArrowRight'
};

function resolveKeyToken(token) {
  const cleaned = token.trim();
  if (!cleaned) {
    throw new Error('Hotkey token is empty.');
  }

  const directAlias = KEY_ALIASES[cleaned.toUpperCase()];
  const lookupKey = directAlias || cleaned.toUpperCase();

  if (/^F[1-9][0-9]?$/.test(lookupKey) && UiohookKey[lookupKey]) {
    return {
      code: UiohookKey[lookupKey],
      label: lookupKey.replace('META', 'Cmd')
    };
  }

  if (/^[A-Z0-9]$/.test(lookupKey) && UiohookKey[lookupKey]) {
    return {
      code: UiohookKey[lookupKey],
      label: lookupKey.toUpperCase()
    };
  }

  if (UiohookKey[lookupKey]) {
    const display = lookupKey
      .replace('CTRL', 'Ctrl')
      .replace('SHIFT', 'Shift')
      .replace('ALT', 'Alt')
      .replace('META', process.platform === 'darwin' ? 'Cmd' : 'Meta');
    return {
      code: UiohookKey[lookupKey],
      label: display.charAt(0).toUpperCase() + display.slice(1)
    };
  }

  throw new Error(`Unsupported hotkey token "${token}".`);
}

function parseHotkey(input) {
  const tokens = input
    .split('+')
    .map((part) => part.trim())
    .filter(Boolean);

  if (!tokens.length) {
    throw new Error('TRANSCRYB_HOTKEY must include at least one key.');
  }

  const resolved = tokens.map(resolveKeyToken);
  return {
    codes: resolved.map((item) => item.code),
    label: resolved.map((item) => item.label).join(' + ')
  };
}

function loadConfig() {
  const hotkeyInput = process.env.TRANSCRYB_HOTKEY || DEFAULT_HOTKEY;
  const hotkey = parseHotkey(hotkeyInput);

  return {
    hotkey,
    autopaste: process.env.TRANSCRYB_AUTO_PASTE !== 'false',
    clipboardOnly: process.env.TRANSCRYB_CLIPBOARD_ONLY === 'true',
    fasterWhisper: {
      url: process.env.FASTER_WHISPER_URL || DEFAULT_API_URL,
      apiKey: process.env.FASTER_WHISPER_API_KEY || '',
      model: process.env.FASTER_WHISPER_MODEL || 'base',
      temperature:
        Number.isFinite(Number(process.env.FASTER_WHISPER_TEMPERATURE))
          ? Number(process.env.FASTER_WHISPER_TEMPERATURE)
          : 0
    }
  };
}

module.exports = {
  loadConfig
};
