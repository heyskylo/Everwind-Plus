import SwiftUI
import WebKit

/// Serves the bundled `V86Assets` directory over a private URL scheme.
///
/// `WKWebView` refuses `fetch()` requests to `file://` URLs, and v86 fetches its
/// WebAssembly runtime and the Linux ISO at start-up. Serving them from our own
/// scheme keeps everything same-origin and lets us set the expected MIME types.
final class V86SchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "everwind"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        guard let root = Bundle.main.url(forResource: "V86Assets", withExtension: nil) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        var relative = url.path
        if relative.isEmpty || relative == "/" {
            relative = "/index.html"
        }

        let fileURL = root.appendingPathComponent(relative).standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        guard fileURL.path.hasPrefix(rootPath),
              fileURL.path != rootPath,
              let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": Self.mimeType(for: fileURL.pathExtension),
                "Content-Length": String(data.count),
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "no-store",
            ]
        )!

        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js":   return "text/javascript; charset=utf-8"
        case "css":  return "text/css; charset=utf-8"
        case "wasm": return "application/wasm"
        case "json": return "application/json"
        case "png":  return "image/png"
        default:     return "application/octet-stream"
        }
    }
}

/// Boots Tiny Core Linux inside the app using the bundled v86 x86 emulator.
///
/// v86 translates guest machine code to WebAssembly, which WebKit compiles
/// ahead of time, so this runs without any JIT entitlement.
struct V86WebView: UIViewRepresentable {
    /// When true the guest picture is stretched to fill the whole screen; when
    /// false it keeps its aspect ratio and is letterboxed.
    var fillScreen: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.setURLSchemeHandler(V86SchemeHandler(), forURLScheme: V86SchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let indexURL = URL(string: "\(V86SchemeHandler.scheme)://local/index.html")!
        webView.load(URLRequest(url: indexURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // No-op until the page has defined the hook.
        webView.evaluateJavaScript(
            "window.everwindSetFill && window.everwindSetFill(\(fillScreen ? "true" : "false"))",
            completionHandler: nil
        )
    }
}

/// Full-screen container for the Tiny Core Linux virtual machine.
struct VirtualMachineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessionID = UUID()
    /// iPhone screens are wider than any display mode the guest supports
    /// (19.5:9 vs 16:9), so filling the screen stretches the picture slightly.
    /// Filling is the default; the toolbar button switches to exact aspect.
    @State private var fillScreen = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            V86WebView(fillScreen: fillScreen)
                .id(sessionID)
                .ignoresSafeArea()

            HStack(spacing: 8) {
                controlButton("aspectratio", label: fillScreen ? "Use exact aspect ratio" : "Fill the screen") {
                    fillScreen.toggle()
                }
                controlButton("arrow.clockwise", label: "Restart") {
                    sessionID = UUID()
                }
                controlButton("xmark", label: "Close") {
                    dismiss()
                }
            }
            .padding(.trailing, 12)
            .padding(.top, 12)
        }
        .statusBarHidden()
        .onAppear {
            AppDelegate.orientationLock = .landscape
            AppDelegate.request(.landscape)
        }
        .onDisappear {
            AppDelegate.orientationLock = nil
            AppDelegate.request(AppDelegate.unlockedOrientations)
        }
    }

    private func controlButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
