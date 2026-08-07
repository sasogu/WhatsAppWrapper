import SwiftUI
import WebKit

@Observable
class WebViewModel {
    var canGoBack = false
    var isLoading = false
    var estimatedProgress: Double = 0
    var error: WebViewError?

    weak var webView: WKWebView?

    struct WebViewError: Identifiable {
        let id = UUID()
        let message: String
    }

    func goBack() {
        webView?.goBack()
    }

    func reload() {
        error = nil
        if webView?.url != nil {
            webView?.reload()
        } else {
            loadInitialURL()
        }
    }

    func loadInitialURL() {
        error = nil
        guard let url = URL(string: "https://web.whatsapp.com") else { return }
        webView?.load(URLRequest(url: url))
    }
}
