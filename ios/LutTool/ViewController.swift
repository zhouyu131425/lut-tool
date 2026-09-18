import UIKit
import WebKit
import UniformTypeIdentifiers

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentPickerDelegate {
    var webView: WKWebView!
    var toolbar: UIToolbar!
    var compareBtn: UIBarButtonItem!
    var origBtn: UIBarButtonItem!
    var crossBtn: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        view.addSubview(webView)

        toolbar = UIToolbar()
        view.addSubview(toolbar)

        webView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let openBtn = UIBarButtonItem(title: "打开照片", style: .plain, target: self, action: #selector(openPhoto))
        compareBtn = UIBarButtonItem(title: "对比：关闭", style: .plain, target: self, action: #selector(tapCompare))
        origBtn = UIBarButtonItem(title: "看原图", style: .plain, target: self, action: #selector(tapOrig))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([openBtn, spacer, compareBtn, origBtn], animated: false)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    @objc func openPhoto() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .image, .jpeg, .png, .heic, .rawImage,
            UTType(filenameExtension: "dng") ?? .data,
            UTType(filenameExtension: "cr2") ?? .data,
            UTType(filenameExtension: "nef") ?? .data,
            UTType(filenameExtension: "arw") ?? .data,
            UTType(filenameExtension: "raf") ?? .data
        ])
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var batch: [[String: String]] = []
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let ext = url.pathExtension.lowercased()
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "webp": mime = "image/webp"
            case "gif": mime = "image/gif"
            case "heic", "heif": mime = "image/heic"
            default: mime = "image/jpeg"
            }
            batch.append(["dataUrl": "data:\(mime);base64,\(data.base64EncodedString())", "name": url.lastPathComponent])
        }
        guard !batch.isEmpty, let json = try? JSONSerialization.data(withJSONObject: batch),
              let payload = String(data: json, encoding: .utf8) else { return }
        let js = "window.__loadPhotoData ? window.__loadPhotoData(\(payload)) : (window.__pendingLoads=\(payload), true)"
        webView.evaluateJavaScript(js) { _, _ in }
    }

    @objc func tapCompare() {
        webView.evaluateJavaScript("document.getElementById('toggleCompare').click()") { _, _ in }
    }
    @objc func tapOrig() {
        webView.evaluateJavaScript("document.getElementById('toggleOrig').click()") { _, _ in }
    }
}
