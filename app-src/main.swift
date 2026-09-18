import Cocoa
import WebKit
import UniformTypeIdentifiers
import CoreImage

/// 照片 LUT 调色工具 — macOS 原生壳
/// WKWebView 加载 Resources/index.html。
/// 两条选图通道：
/// 1. 页面内透明覆盖式 <input type="file">（真实点击由 WebKit 原生弹面板，最可靠）；
/// 2. 菜单「文件 → 打开照片…(⌘O) / 打开 LUT…(⇧⌘O)」：Swift NSOpenPanel → base64 → 注入页面。
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationWillFinishLaunching(_ notification: Notification) {
        buildMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()   // 不留任何缓存/历史
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        createWindow()

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    // 页面加载完成后探测注入入口是否就绪（诊断用）
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.evaluateJavaScript("(window.__initErr||'')+'|'+(window.__initDone||0)+'|'+typeof window.__loadPhotoData") { result, _ in
                if let r = result as? String { self.bridgeLog("pagefn:\(r)") }
                else { self.bridgeLog("pagefn:unknown") }
            }
        }
    }

    func createWindow() {
        let rect = NSRect(x: 0, y: 0, width: 1180, height: 820)
        let w = NSWindow(contentRect: rect,
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "照片 LUT 调色工具"
        w.minSize = NSSize(width: 720, height: 640)
        w.center()
        w.setFrameAutosaveName("LutToolMainWindow")
        // 默认 isReleasedWhenClosed=true：关窗即释放窗口并触发 applicationShouldTerminateAfterLastWindowClosed 退出 App，
        // 避免"窗口关闭但进程残留、Dock 重开不重建"的假死状态
        webView.autoresizingMask = [.width, .height]
        webView.frame = w.contentView!.bounds
        w.contentView?.addSubview(webView)
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Dock 点击时若窗口已不存在则重建
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, window == nil {
            createWindow()
        }
        return true
    }

    // 弹窗（alert/confirm）直接走系统弹窗，避免被 WKWebView 拦截
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "照片 LUT 调色工具"
        alert.informativeText = message
        alert.runModal()
        completionHandler()
    }

    // MARK: - 打开文件（菜单通道）

    enum PickKind { case photo, lut }

    private func bridgeLog(_ s: String) {
        let line = s + "\n"
        guard let d = line.data(using: .utf8) else { return }
        let url = URL(fileURLWithPath: "/tmp/lut_menu.log")
        if FileManager.default.fileExists(atPath: url.path) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile()
                h.write(d)
                try? h.close()
            }
        } else {
            try? d.write(to: url)
        }
    }

    @objc func openPhoto(_ sender: Any?) { pickFiles(kind: .photo) }
    @objc func openLut(_ sender: Any?) { pickFiles(kind: .lut) }

    // 用 JSON 编码生成安全的 JS 字符串字面量（含双引号与转义），避免手工转义破坏语法
    private func jsStr(_ s: String) -> String {
        let d = try! JSONSerialization.data(withJSONObject: [s])
        var str = String(data: d, encoding: .utf8) ?? "\"\""
        str.removeFirst()  // [
        str.removeLast()   // ]
        return str
    }

    private func pickFiles(kind: PickKind) {
        bridgeLog("menu:\(kind == .photo ? "photo" : "lut")")
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = kind == .photo ? "选择照片（可多选，含 RAW）" : "选择 .cube LUT 文件（可多选）"
        if kind == .photo {
            panel.allowedContentTypes = [.jpeg, .png, .webP, .heic, .tiff, UTType("public.camera-raw-image") ?? .data]
        } else {
            panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .data]
        }
        if panel.runModal() == .OK {
            bridgeLog("panel:ok count=\(panel.urls.count)")
            for url in panel.urls {
                if kind == .photo, rawExts.contains(url.pathExtension.lowercased()) {
                    // RAW：Core Image 原生解码（DNG/CR2/NEF/ARW…）→ 缩至 ≤2400 → JPEG → 注入
                    if let jpeg = decodeRawToJpeg(url) {
                        let b64 = jpeg.base64EncodedString()
                        let js = "window.__loadPhotoData(\(jsStr("data:image/jpeg;base64,\(b64)")),\(jsStr(url.lastPathComponent)))"
                        webView.evaluateJavaScript(js) { _, err in
                            self.bridgeLog(err == nil ? "raw:ok \(url.lastPathComponent)" : "raw:err \(url.lastPathComponent)")
                        }
                    } else {
                        bridgeLog("raw:fail \(url.lastPathComponent)")
                    }
                    continue
                }
                guard let data = try? Data(contentsOf: url) else { bridgeLog("read:fail \(url.lastPathComponent)"); continue }
                let b64 = data.base64EncodedString()
                let mime: String
                if kind == .photo {
                    mime = url.pathExtension.lowercased() == "png" ? "image/png"
                         : url.pathExtension.lowercased() == "webp" ? "image/webp"
                         : url.pathExtension.lowercased() == "heic" ? "image/heic"
                         : "image/jpeg"
                } else {
                    mime = "text/plain"
                }
                let fn = kind == .photo ? "__loadPhotoData" : "__loadLutData"
                let js = "window.\(fn)(\(jsStr("data:\(mime);base64,\(b64)")),\(jsStr(url.lastPathComponent)))"
                webView.evaluateJavaScript(js) { _, err in
                    if err == nil {
                        self.bridgeLog("inject:ok \(url.lastPathComponent)")
                    } else {
                        self.bridgeLog("inject:err \(String(describing: err!))")
                    }
                }
            }
            // LUT 多选注入完成后，通知页面一次性进入分组确认（照片无需）
            if kind == .lut {
                webView.evaluateJavaScript("window.__flushLutImport && window.__flushLutImport()") { _, err in
                    self.bridgeLog(err == nil ? "flush:ok" : "flush:err")
                }
                // 诊断：注入后延迟读取渲染自检结果（中心像素 RGBA/GL 错误/引擎文案），仅写 /tmp 日志
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.webView.evaluateJavaScript("JSON.stringify({diag:window.__glDiag||null,err:window.__glErr||null,eng:(document.getElementById('engineInfo')||{}).textContent||''})") { r, _ in
                        if let s = r as? String { self.bridgeLog("state:\(s)") }
                    }
                }
            } else {
                // 照片诊断
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.webView.evaluateJavaScript("JSON.stringify({diag:window.__glDiag||null,err:window.__glErr||null,eng:(document.getElementById('engineInfo')||{}).textContent||''})") { r, _ in
                        if let s = r as? String { self.bridgeLog("state:\(s)") }
                    }
                }
            }
        } else {
            bridgeLog("panel:cancel")
        }
    }

    private let rawExts: Set<String> = ["dng","cr2","cr3","nef","arw","raf","orf","rw2","srw","pef","raw","3fr","fff","iiq"]

    // Core Image RAW 解码：CIRAWFilter 支持 DNG/CR2/CR3/NEF/ARW/RAF/ORF/RW2 等 → 缩放 ≤2400 → JPEG
    private func decodeRawToJpeg(_ url: URL) -> Data? {
        guard let out = (CIRAWFilter(imageURL: url)?.outputImage) ?? CIImage(contentsOf: url) else { return nil }
        var extent = out.extent
        if extent.width < 2 || extent.height < 2 { return nil }
        var image = out
        let maxDim = 2400.0
        let m = max(extent.width, extent.height)
        if m > maxDim {
            let s = maxDim / m
            image = out.transformed(by: CGAffineTransform(scaleX: s, y: s))
        }
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return ctx.jpegRepresentation(of: image, colorSpace: cs, options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.9])
    }

    // MARK: - 菜单

    @objc func zoomIn(_ sender: Any?) {
        webView.magnification = min(webView.magnification * 1.25, 3.0)
    }
    @objc func zoomOut(_ sender: Any?) {
        webView.magnification = max(webView.magnification / 1.25, 0.4)
    }
    @objc func zoomActual(_ sender: Any?) {
        webView.magnification = 1.0
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 照片 LUT 调色工具",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 照片 LUT 调色工具",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        let op = NSMenuItem(title: "打开照片…", action: #selector(openPhoto(_:)), keyEquivalent: "o")
        op.target = self
        fileMenu.addItem(op)
        let ol = NSMenuItem(title: "打开 LUT…", action: #selector(openLut(_:)), keyEquivalent: "O")
        ol.keyEquivalentModifierMask = [.command, .shift]
        ol.target = self
        fileMenu.addItem(ol)
        fileItem.submenu = fileMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "显示")
        let zo = NSMenuItem(title: "实际大小", action: #selector(zoomActual(_:)), keyEquivalent: "0")
        zo.target = self
        viewMenu.addItem(zo)
        let zi = NSMenuItem(title: "放大", action: #selector(zoomIn(_:)), keyEquivalent: "+")
        zi.target = self
        viewMenu.addItem(zi)
        let zo2 = NSMenuItem(title: "缩小", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        zo2.target = self
        viewMenu.addItem(zo2)
        viewMenu.addItem(.separator())
        let full = NSMenuItem(title: "进入全屏幕", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(full)
        viewItem.submenu = viewMenu

        let winItem = NSMenuItem()
        mainMenu.addItem(winItem)
        let winMenu = NSMenu(title: "窗口")
        winMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = winMenu
        NSApp.windowsMenu = winMenu

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
