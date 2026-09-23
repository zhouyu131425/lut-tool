# 照片LUT调色工具（LutTool）

上传照片 → 按 LUT 调色 → 批量导出，全部在本地完成，**不会上传任何照片**。

## 功能

- **16 个内置预设**：索尼 S-Log3 → Rec.709/sRGB 官方公式还原、富士胶片模拟（Classic Neg./NC、Classic Chrome/CC、Reala Ace/RA、Velvia、ASTIA、PROVIA、ETERNA，基于富士官方 F-Log2C 色彩科学）、iPhone 通透、复古胶片等
- **自定义 LUT**：导入 .cube（3D 17/33/65 点与 1D），支持 TITLE / DOMAIN 声明，可重命名、分组（索尼/佳能/RED/尼康/大疆等），本地持久化保存
- **对比分割**：左右 / 上下分割对比原图与调色效果，分割线可拖动
- **构图参考线**：十字线、三分网格、黄金分割、对角线、安全框
- **批量处理**：一次选择多张照片，点击队列或“上一张/下一张”切换预览，统一套用 LUT 与强度，一键导出 ZIP
- **RAW 支持**：macOS 原生版可解码 DNG/CR2/NEF/ARW 等单反 RAW
- **渲染引擎**：WebGL2 硬件三线性插值（自动降级 CPU）

## 快速开始

直接用浏览器打开 `照片LUT调色工具.html`（单文件、零依赖、离线可用）。

或下载各平台安装包（见 [Releases](https://github.com/zhouyu131425/lut-tool/releases)）：

| 平台 | 安装包 |
|---|---|
| macOS（Apple 芯片） | `LutTool-macOS-arm64.dmg` |
| Windows | `LutTool-1.0.0-win-x64.exe`（安装版）/ `LutTool-win-x64-portable.zip`（绿色版） |
| Linux | `LutTool-linux-x86_64.AppImage` |
| iOS / Android | Xcode / Android Studio 工程源码（见 `ios/`、`android/`） |

## 目录结构

```
├── 照片LUT调色工具.html    # 主程序（唯一源文件，单文件自包含）
├── app-src/                # macOS 原生 App（Swift + WKWebView）
├── desktop/                # Windows/Linux 跨平台版（Electron）
├── ios/                    # iOS 工程（Xcode）
├── android/                # Android 工程（Capacitor / Android Studio）
└── scripts/                # 平台页面同步与一致性校验
```

## 同步平台页面

`照片LUT调色工具.html` 是唯一源文件。不要直接编辑 `desktop/`、`ios/`、`android/` 里的页面副本。

同步到所有平台：

```bash
node scripts/sync-html.mjs
```

只检查一致性：

```bash
node scripts/sync-html.mjs --check
```

## 从源码构建

- **macOS**：`cd app-src && bash build.sh`
- **Windows / Linux**：`cd desktop && npm install && npm run dist:win`（或 `npm run dist:linux`）
- **iOS**：先运行 `node scripts/sync-html.mjs`，再用 Xcode 打开 `ios/LutTool.xcodeproj`
- **Android**：先运行 `node scripts/sync-html.mjs`，再用 Android Studio 打开 `android/android`

## 技术说明

- 索尼还原 LUT 按官方 S-Log3 编码公式与 S-Gamut3.Cine 色域矩阵生成，属技术性还原
- 富士胶片模拟基于富士官方 F-Log2C 3D-LUT 色彩科学复合构建；Nostalgic Neg. 官方暂未随 LUT 发布
- 其余内置风格为程序生成的风格化近似，并非相机厂商官方 LUT

## License

MIT
