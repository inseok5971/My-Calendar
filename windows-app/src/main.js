const { app, BrowserWindow, ipcMain, shell, dialog, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow = null;
let miniBoardWindow = null;
let tray = null;
let currentMode = 'main'; // 'main' | 'mini'

function getDataDir() {
  try {
    return path.join(app.getPath('userData'), 'MyCalendarData');
  } catch (e) {
    return path.join(process.env.APPDATA || process.env.USERPROFILE || process.env.HOME || '.', 'MyCalendarData');
  }
}

function getDataFilePath() {
  return path.join(getDataDir(), 'calendar_store.json');
}

function ensureDataFile() {
  const dir = getDataDir();
  const filePath = getDataFilePath();
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  if (!fs.existsSync(filePath)) {
    const initialData = {
      events: [],
      todos: [],
      settings: {
        theme: 'system',
        mainWindowOpacity: 1.0,
        stickyWindowOpacity: 0.95,
        isMiniBoardPinnedOnTop: true,
        lastWindowMode: 'main'
      }
    };
    fs.writeFileSync(filePath, JSON.stringify(initialData, null, 2), 'utf-8');
  }
}

function loadStoreData() {
  ensureDataFile();
  try {
    const raw = fs.readFileSync(getDataFilePath(), 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    return { events: [], todos: [], settings: {} };
  }
}

function saveStoreData(data) {
  ensureDataFile();
  try {
    fs.writeFileSync(getDataFilePath(), JSON.stringify(data, null, 2), 'utf-8');
    return true;
  } catch (e) {
    console.error('Failed to save data:', e);
    return false;
  }
}

const appIconPath = path.join(__dirname, '../assets/icon.png');
const trayIconPath = path.join(__dirname, '../assets/tray.png');

function createTrayIcon() {
  if (fs.existsSync(trayIconPath)) {
    return nativeImage.createFromPath(trayIconPath);
  }
  const iconCanvas = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEKADAAQAAAABAAAAEAAAAAA0YuksAAAAeElEQVQ4y2P8//8/AyWACbEQqxmEQcDMQA5gHFUYwMAw6sBoGIyGAGbEU4D5PzZ5vBpgmtEVMDIwMBDF6GIwzfgUoGvGpwCtDYhVjC4G04zPClQD0I1CF0PXjM8KdAOINgBkJjY9yG7EKkY2YxQjVjG6GKMhaAEAKwIqE/97iGIAAAAASUVORK5CYII=',
    'base64'
  );
  return nativeImage.createFromBuffer(iconCanvas);
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 780,
    minWidth: 960,
    minHeight: 640,
    title: '나만의 캘린더',
    icon: appIconPath,
    backgroundColor: '#f8fafc',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  mainWindow.on('close', (e) => {
    if (!app.isQuitting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });
}

function createMiniBoardWindow() {
  miniBoardWindow = new BrowserWindow({
    width: 340,
    height: 500,
    minWidth: 300,
    minHeight: 380,
    title: '미니 보드',
    icon: appIconPath,
    frame: false,
    alwaysOnTop: true,
    backgroundColor: '#ffffff',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  miniBoardWindow.loadFile(path.join(__dirname, 'renderer', 'mini.html'));

  miniBoardWindow.on('close', (e) => {
    if (!app.isQuitting) {
      e.preventDefault();
      miniBoardWindow.hide();
    }
  });
}

function setupTray() {
  tray = new Tray(createTrayIcon());
  tray.setToolTip('나만의 캘린더');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: '📅 스케줄러 열기',
      click: () => switchToMainWindow()
    },
    {
      label: '📌 미니 보드 열기 (항상 위)',
      click: () => switchToMiniBoard()
    },
    { type: 'separator' },
    {
      label: '종료',
      click: () => {
        app.isQuitting = true;
        app.quit();
      }
    }
  ]);

  tray.setContextMenu(contextMenu);
  tray.on('click', () => {
    if (currentMode === 'mini') {
      if (miniBoardWindow && miniBoardWindow.isVisible()) {
        miniBoardWindow.hide();
      } else {
        switchToMiniBoard();
      }
    } else {
      if (mainWindow && mainWindow.isVisible()) {
        mainWindow.hide();
      } else {
        switchToMainWindow();
      }
    }
  });
}

function switchToMainWindow() {
  currentMode = 'main';
  if (mainWindow) {
    mainWindow.show();
    mainWindow.focus();
  }
  if (miniBoardWindow) miniBoardWindow.hide();
}

function switchToMiniBoard() {
  currentMode = 'mini';
  if (miniBoardWindow) {
    miniBoardWindow.show();
    miniBoardWindow.focus();
  }
  if (mainWindow) mainWindow.hide();
}

// IPC Handlers
ipcMain.handle('get-data', () => {
  return loadStoreData();
});

ipcMain.handle('save-data', (event, data) => {
  const ok = saveStoreData(data);
  // Broadcast update to both windows
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('data-updated', data);
  }
  if (miniBoardWindow && !miniBoardWindow.isDestroyed()) {
    miniBoardWindow.webContents.send('data-updated', data);
  }
  return ok;
});

ipcMain.handle('switch-to-mini', () => {
  switchToMiniBoard();
});

ipcMain.handle('switch-to-main', () => {
  switchToMainWindow();
});

ipcMain.handle('choose-folder', async () => {
  const win = currentMode === 'mini' ? miniBoardWindow : mainWindow;
  const result = await dialog.showOpenDialog(win, {
    title: '연결할 프로젝트 폴더 선택',
    properties: ['openDirectory']
  });
  if (result.canceled || result.filePaths.length === 0) {
    return null;
  }
  return result.filePaths[0];
});

ipcMain.handle('open-folder', async (event, folderPath) => {
  if (folderPath) {
    const normalized = path.normalize(folderPath);
    if (fs.existsSync(normalized)) {
      await shell.openPath(normalized);
      return true;
    }
  }
  return false;
});

ipcMain.handle('set-mini-always-on-top', (event, isPinned) => {
  if (miniBoardWindow) {
    miniBoardWindow.setAlwaysOnTop(isPinned);
  }
});

ipcMain.handle('set-mini-opacity', (event, opacity) => {
  if (miniBoardWindow) {
    miniBoardWindow.setOpacity(Math.max(0.35, Math.min(1.0, opacity)));
  }
});

app.whenReady().then(() => {
  createMainWindow();
  createMiniBoardWindow();
  setupTray();

  const data = loadStoreData();
  if (data.settings && data.settings.lastWindowMode === 'mini') {
    switchToMiniBoard();
  } else {
    switchToMainWindow();
  }
});

app.on('window-all-closed', (e) => {
  // Keep app active in Windows system tray
  e.preventDefault();
});
