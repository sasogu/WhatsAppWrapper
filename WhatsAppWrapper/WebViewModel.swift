import SwiftUI
import WebKit

struct WebService: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let url: URL
    let allowedHostSuffixes: [String]

    static let whatsapp = WebService(
        id: "whatsapp",
        name: "WhatsApp",
        systemImage: "message",
        url: URL(string: "https://web.whatsapp.com")!,
        allowedHostSuffixes: ["whatsapp.com", "whatsapp.net", "fbcdn.net"]
    )

    // Las pestañas personales se definen en Services.local.swift (fuera de git).
    static let all: [WebService] = [whatsapp] + local
}

@Observable
class WebViewModel {
    let service: WebService

    var canGoBack = false
    var isLoading = false
    var estimatedProgress: Double = 0
    var error: WebViewError?

    weak var webView: WKWebView?

    struct WebViewError: Identifiable {
        let id = UUID()
        let message: String
    }

    init(service: WebService) {
        self.service = service
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
        webView?.load(URLRequest(url: service.url))
    }
}
