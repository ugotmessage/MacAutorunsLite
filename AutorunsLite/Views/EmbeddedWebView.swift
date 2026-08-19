import SwiftUI
import WebKit

@MainActor
final class EmbeddedBrowserController: NSObject, ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var currentURL: URL?
    @Published var loadFailed = false

    fileprivate weak var webView: WKWebView?

    func load(_ url: URL) {
        loadFailed = false
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        loadFailed = false
        if webView?.url != nil {
            webView?.reload()
        } else if let currentURL {
            webView?.load(URLRequest(url: currentURL))
        }
    }

    fileprivate func sync(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        currentURL = webView.url
    }
}

struct EmbeddedWebView: NSViewRepresentable {
    @ObservedObject var controller: EmbeddedBrowserController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        controller.webView = webView
        context.coordinator.observe(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        controller.webView = nsView
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let controller: EmbeddedBrowserController
        private var observations: [NSKeyValueObservation] = []

        init(controller: EmbeddedBrowserController) {
            self.controller = controller
        }

        func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.canGoBack, options: [.new]) { [weak controller] view, _ in
                    DispatchQueue.main.async { controller?.sync(from: view) }
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak controller] view, _ in
                    DispatchQueue.main.async { controller?.sync(from: view) }
                },
                webView.observe(\.isLoading, options: [.new]) { [weak controller] view, _ in
                    DispatchQueue.main.async { controller?.sync(from: view) }
                },
                webView.observe(\.url, options: [.new]) { [weak controller] view, _ in
                    DispatchQueue.main.async { controller?.sync(from: view) }
                }
            ]
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" || scheme.isEmpty {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.controller.loadFailed = true
                self.controller.sync(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            DispatchQueue.main.async {
                self.controller.loadFailed = true
                self.controller.sync(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.controller.loadFailed = false
                self.controller.sync(from: webView)
            }
        }
    }
}
