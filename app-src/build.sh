#!/bin/bash
# 构建「照片 LUT 调色工具.app」——需要 macOS + Xcode 命令行工具（swiftc）
# 用法：bash build.sh   （在 app-src 目录内运行）
set -euo pipefail
cd "$(dirname "$0")"

SRC_HTML="../照片LUT调色工具.html"          # 工具页面（相对 app-src 的上级目录）
APP_NAME="照片LUT调色工具"
APP_OUT="../${APP_NAME}.app"
SDK="$(xcrun --show-sdk-path)"

echo "[1/4] 编译 App 可执行文件…"
swiftc -O -sdk "$SDK" main.swift -o LutTool -framework Cocoa -framework WebKit

echo "[2/4] 生成图标…"
swiftc -O -sdk "$SDK" make_icon.swift -o make_icon -framework AppKit
./make_icon AppIcon.png
sips -s format icns AppIcon.png --out AppIcon.icns >/dev/null
rm -f make_icon AppIcon.png

echo "[3/4] 组装 .app 结构…"
rm -rf "$APP_OUT"
mkdir -p "$APP_OUT/Contents/MacOS" "$APP_OUT/Contents/Resources"
cp LutTool "$APP_OUT/Contents/MacOS/LutTool"
cp "$SRC_HTML" "$APP_OUT/Contents/Resources/index.html"
cp AppIcon.icns "$APP_OUT/Contents/Resources/AppIcon.icns"
cat > "$APP_OUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>LutTool</string>
  <key>CFBundleIdentifier</key><string>com.local.luttool</string>
  <key>CFBundleName</key><string>照片LUT调色工具</string>
  <key>CFBundleDisplayName</key><string>照片 LUT 调色工具</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>本地工具 · 照片不上传服务器</string>
</dict>
</plist>
PLIST
chmod +x "$APP_OUT/Contents/MacOS/LutTool"

echo "[4/4] 结构校验…"
plutil -lint "$APP_OUT/Contents/Info.plist"
test -x "$APP_OUT/Contents/MacOS/LutTool" && echo "可执行文件 OK"
test -f "$APP_OUT/Contents/Resources/index.html" && echo "页面资源 OK"
test -f "$APP_OUT/Contents/Resources/AppIcon.icns" && echo "图标 OK"
echo "完成：$APP_OUT"
