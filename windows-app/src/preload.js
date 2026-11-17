const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getData: () => ipcRenderer.invoke('get-data'),
  saveData: (data) => ipcRenderer.invoke('save-data', data),
  switchToMini: () => ipcRenderer.invoke('switch-to-mini'),
  switchToMain: () => ipcRenderer.invoke('switch-to-main'),
  chooseFolder: () => ipcRenderer.invoke('choose-folder'),
  openFolder: (folderPath) => ipcRenderer.invoke('open-folder', folderPath),
  setMiniAlwaysOnTop: (isPinned) => ipcRenderer.invoke('set-mini-always-on-top', isPinned),
  setMiniOpacity: (opacity) => ipcRenderer.invoke('set-mini-opacity', opacity),
  onDataUpdated: (callback) => {
    ipcRenderer.on('data-updated', (event, data) => callback(data));
  }
});
