'use strict';
const { app, BrowserWindow, Menu, dialog, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

let win = null;

/* 照片文件读取 → base64 注入页面（与网页版 window.__loadPhotoData 一致） */
function loadFiles(filePaths) {
  if (!win) return;
  const batch = [];
  for (const fp of filePaths) {
    try {
      const buf = fs.readFileSync(fp);
      const ext = path.extname(fp).slice(1).toLowerCase();
      const mime = ext === 'png' ? 'image/png'
        : ext === 'webp' ? 'image/webp'
        : ext === 'gif' ? 'image/gif'
        : ext === 'bmp' ? 'image/bmp'
        : ext === 'avif' ? 'image/avif'
        : ext === 'heic' || ext === 'heif' ? 'image/heic'
        : 'image/jpeg';
      const dataUrl = `data:${mime};base64,${buf.toString('base64')}`;
      batch.push({ dataUrl, name: path.basename(fp) });
    } catch (e) { /* 跳过读取失败文件 */ }
  }
  if (!batch.length) return;
  const payload = JSON.stringify(batch).replace(/</g, '\\u003c');
  win.webContents.executeJavaScript(
    `window.__loadPhotoData ? window.__loadPhotoData(${payload}) : (window.__pendingLoads=${payload}, true)`
  ).catch(() => {});
}

function openPhotos() {
  if (!win) return;
  dialog.showOpenDialog(win, {
    title: '选择照片（可多选，支持批量）',
    properties: ['openFile', 'multiSelections'],
    filters: [
      { name: '照片', extensions: ['jpg','jpeg','png','webp','gif','bmp','avif','heic','heif','dng','cr2','nef','arw','raf','rw2'] },
      { name: '所有文件', extensions: ['*'] }
    ]
  }).then(r => { if (!r.canceled && r.filePaths.length) loadFiles(r.filePaths); });
}

function createMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac ? [{ role: 'appMenu' }] : []),
    {
      label: '文件',
      submenu: [
        { label: '打开照片…', accelerator: 'CmdOrCtrl+O', click: openPhotos },
        { type: 'separator' },
        isMac ? { role: 'close' } : { role: 'quit', label: '退出' }
      ]
    },
    { role: 'editMenu', label: '编辑' },
    { role: 'viewMenu', label: '视图' },
    { role: 'windowMenu', label: '窗口' }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function createWindow() {
  win = new BrowserWindow({
    width: 1320,
    height: 900,
    minWidth: 960,
    minHeight: 640,
    title: '照片LUT调色工具',
    icon: path.join(__dirname, 'build', process.platform === 'darwin' ? 'icon.icns' : process.platform === 'win32' ? 'icon.ico' : 'icon.png'),
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false
    }
  });
  win.loadFile(path.join(__dirname, '照片LUT调色工具.html'));
  /* 拖入文件默认导航拦截：交给页面 File API 处理 */
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  win.on('closed', () => { win = null; });
}

app.whenReady().then(() => {
  createMenu();
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
