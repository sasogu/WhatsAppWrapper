import SwiftUI
import WebKit

struct WebService: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let url: URL
    let allowedHostSuffixes: [String]

    static let all: [WebService] = [
        WebService(
            id: "whatsapp",
            name: "WhatsApp",
            systemImage: "message",
            url: URL(string: "https://web.whatsapp.com")!,
            allowedHostSuffixes: ["whatsapp.com", "whatsapp.net", "fbcdn.net"]
        ),
        WebService(
            id: "snappymail",
            name: "Correo",
            systemImage: "envelope",
            url: URL(string: "https://mail.example.org/")!,
            allowedHostSuffixes: ["example.org"]
        ),
        WebService(
            id: "tasks",
            name: "Tareas",
            systemImage: "checklist",
            url: URL(string: "https://tasks.example.org/")!,
            allowedHostSuffixes: ["example.org"]
        )
    ]
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
