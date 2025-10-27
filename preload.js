const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  transcribeWav: async (wavArrayBuffer) => {
    return await ipcRenderer.invoke('transcribe-wav', { wavBuffer: new Uint8Array(wavArrayBuffer) });
  }
});
