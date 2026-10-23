import UIKit
import WebKit
import UniformTypeIdentifiers

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = WebViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var web: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "app")
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.backgroundColor = .white
        view = web
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        web.load(URLRequest(url: URL(string: "app://local/index.html")!))
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.scheme != "app", url.scheme != "about" else { return decisionHandler(.allow) }
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }

    // window.open / target=_blank links open in Safari.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
    }
}

final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root = Bundle.main.resourceURL!.appendingPathComponent("www").standardizedFileURL

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var p = url.path
        if p.isEmpty || p.hasSuffix("/") { p += "index.html" }
        let file = root.appendingPathComponent(String(p.drop(while: { $0 == "/" }))).standardizedFileURL
        guard file.path.hasPrefix(root.path), let data = try? Data(contentsOf: file) else {
            task.didReceive(HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!)
            task.didFinish()
            return
        }
        var mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        if file.pathExtension == "js" || file.pathExtension == "mjs" { mime = "text/javascript" }
        if mime.hasPrefix("text/") { mime += "; charset=utf-8" }
        task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                        headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)"])!)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
