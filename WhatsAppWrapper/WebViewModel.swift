import SwiftUI
import WebKit

struct WebService: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let systemImage: String
    let url: URL
    let allowedHostSuffixes: [String]
    var prefersDesktop = true
    var opensExternalLinksInBrowser = true

    static let whatsapp = WebService(
        id: "whatsapp",
        name: "WhatsApp",
        systemImage: "message",
        url: URL(string: "https://web.whatsapp.com")!,
        allowedHostSuffixes: ["whatsapp.com", "whatsapp.net", "fbcdn.net"]
    )

    // Importación única de la configuración anterior, si existe en este build.
    // Las instalaciones genéricas empiezan sin webs predefinidas.
    static var initialServices: [WebService] { local.isEmpty ? [] : [whatsapp] + local }

    func allowsHost(_ host: String) -> Bool {
        let host = host.lowercased()
        return allowedHostSuffixes.contains {
            let suffix = $0.lowercased()
            return host == suffix || host.hasSuffix("." + suffix)
        }
    }

    static func validated(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        systemImage: String = "globe",
        prefersDesktop: Bool = false,
        opensExternalLinksInBrowser: Bool = false
    ) throws -> WebService {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ValidationError.nameRequired }
        guard !address.isEmpty,
              address.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw ValidationError.invalidAddress
        }
        let hasSchemeSeparator = address.contains("://")
        let isHostAndPort = address.range(of: #"^[A-Za-z0-9.-]+:[0-9]+(?:[/?#]|$)"#,
                                         options: .regularExpression) != nil
        if !hasSchemeSeparator, URLComponents(string: address)?.scheme != nil, !isHostAndPort {
            throw ValidationError.invalidAddress
        }
        let candidate = hasSchemeSeparator ? address : "https://" + address
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else {
            throw ValidationError.invalidAddress
        }
        // Conserva las excepciones de WhatsApp al editar su nombre o apariencia.
        let hosts = host == "web.whatsapp.com" ? whatsapp.allowedHostSuffixes : [host]
        return WebService(id: id, name: name, systemImage: systemImage, url: url,
                          allowedHostSuffixes: hosts, prefersDesktop: prefersDesktop,
                          opensExternalLinksInBrowser: opensExternalLinksInBrowser)
    }

    enum ValidationError: LocalizedError {
        case nameRequired, invalidAddress

        var errorDescription: String? {
            switch self {
            case .nameRequired: "Escribe un nombre para la web."
            case .invalidAddress: "Introduce una dirección HTTP o HTTPS válida, sin espacios ni credenciales."
            }
        }
    }
}

@Observable
final class WebServiceStore {
    private(set) var services: [WebService]
    @ObservationIgnored private let defaults: UserDefaults
    static let storageKey = "web-services.v1"

    static func applicationStore() -> WebServiceStore {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["WEB_SERVICES_UI_TESTING"] == "1" {
            let suite = "WebServices.UITests"
            let defaults = UserDefaults(suiteName: suite)!
            if ProcessInfo.processInfo.environment["WEB_SERVICES_UI_RESET"] == "1" {
                defaults.removePersistentDomain(forName: suite)
            }
            return WebServiceStore(defaults: defaults, initialServices: [])
        }
        #endif
        return WebServiceStore()
    }

    init(defaults: UserDefaults = .standard, initialServices: [WebService] = WebService.initialServices) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([WebService].self, from: data) {
            services = saved
        } else {
            // Conserva una copia si hubiera datos de una versión incompatible.
            if let data = defaults.data(forKey: Self.storageKey) {
                defaults.set(data, forKey: Self.storageKey + ".backup")
            }
            services = initialServices
            persist()
        }
    }

    func save(_ service: WebService) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index] = service
        } else {
            services.append(service)
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        services.remove(atOffsets: offsets)
        persist()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        services.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(services) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@Observable
class WebViewModel {
    let service: WebService

    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var isClearingCache = false
    var estimatedProgress: Double = 0
    var error: WebViewError?
    var webViewID = UUID()

    weak var webView: WKWebView?
    private var nextURL: URL?
    private var ignoreCacheOnNextLoad = false

    struct WebViewError: Identifiable {
        let id = UUID()
        let message: String
    }

    init(service: WebService) { self.service = service }

    func goBack() {
        guard !isClearingCache else { return }
        webView?.goBack()
    }

    func goForward() {
        guard !isClearingCache else { return }
        webView?.goForward()
    }

    func goHome() {
        guard !isClearingCache else { return }
        nextURL = nil
        loadInitialURL()
    }

    func reload() {
        guard !isClearingCache else { return }
        error = nil
        if webView?.url != nil { webView?.reloadFromOrigin() }
        else { loadInitialURL() }
    }

    func clearCacheAndReload() {
        guard !isClearingCache, let webView else { return }
        isClearingCache = true
        error = nil
        webView.stopLoading()
        let reloadURL = webView.url ?? service.url
        // Las pestañas comparten el almacén. Conservamos cookies y datos de sesión.
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache
        ]
        webView.configuration.websiteDataStore.removeData(
            ofTypes: cacheTypes, modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.nextURL = reloadURL
                self.ignoreCacheOnNextLoad = true
                self.canGoBack = false
                self.canGoForward = false
                self.estimatedProgress = 0
                self.isClearingCache = false
                // Un visor nuevo evita reutilizar el documento y los scripts cargados.
                self.webViewID = UUID()
            }
        }
    }

    func loadInitialURL() {
        error = nil
        let request = URLRequest(url: nextURL ?? service.url,
                                 cachePolicy: ignoreCacheOnNextLoad ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy)
        nextURL = nil
        ignoreCacheOnNextLoad = false
        webView?.load(request)
    }
}
