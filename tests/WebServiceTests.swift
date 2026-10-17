import Foundation

@main
struct WebServiceTests {
    @MainActor
    static func main() throws {
        let suite = "WebServicesTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = try WebService.validated(id: "first", name: "  Primera  ", address: "example.org/app#/inbox")
        precondition(first.name == "Primera")
        precondition(first.url.scheme == "https" && first.url.fragment == "/inbox")
        precondition(!first.prefersDesktop && !first.opensExternalLinksInBrowser)
        let second = try WebService.validated(id: "second", name: "Segunda", address: "http://127.0.0.1:8090/", prefersDesktop: true)
        precondition(second.url.port == 8090 && second.prefersDesktop)
        _ = try WebService.validated(name: "Local", address: "localhost:8080/")
        _ = try WebService.validated(name: "IPv6", address: "http://[::1]:8080/")
        print("OK: HTTPS automático, HTTP local, puertos, fragmentos y preferencias")

        for address in ["", "https://", "javascript:alert(1)", "javascript://example.org", "file:///tmp/file", "file:/tmp/file", "mailto:test@example.org", "https://user:password@example.org", "https://exa mple.org"] {
            do {
                _ = try WebService.validated(name: "Inválida", address: address)
                preconditionFailure("Se aceptó una dirección no válida")
            } catch is WebService.ValidationError { }
        }
        do {
            _ = try WebService.validated(name: "   ", address: "example.org")
            preconditionFailure("Se aceptó un nombre vacío")
        } catch is WebService.ValidationError { }
        precondition(WebService.whatsapp.allowsHost("web.whatsapp.com"))
        precondition(WebService.whatsapp.allowsHost("media.whatsapp.net"))
        precondition(!WebService.whatsapp.allowsHost("evilwhatsapp.com"))
        precondition(!WebService.whatsapp.allowsHost("whatsapp.com.example.org"))
        print("OK: validación de direcciones y límites de dominio")

        let store = WebServiceStore(defaults: defaults, initialServices: [first, second])
        precondition(store.services == [first, second])
        let restored = WebServiceStore(defaults: defaults, initialServices: [])
        precondition(restored.services == [first, second])
        let renamed = try WebService.validated(id: second.id, name: "Renombrada", address: "example.net", prefersDesktop: false, opensExternalLinksInBrowser: true)
        restored.save(renamed)
        precondition(restored.services.count == 2 && restored.services[1] == renamed)
        let third = try WebService.validated(id: "third", name: "Tercera", address: "example.com")
        restored.save(third)
        restored.move(from: IndexSet(integer: 2), to: 0)
        precondition(restored.services.map(\.id) == ["third", "first", "second"])
        let reordered = WebServiceStore(defaults: defaults, initialServices: [])
        precondition(reordered.services == restored.services)
        reordered.remove(at: IndexSet([0, 1, 2]))
        let empty = WebServiceStore(defaults: defaults, initialServices: [first])
        precondition(empty.services.isEmpty)
        print("OK: importación única, alta, edición, orden, eliminación y persistencia de lista vacía")

        let corrupt = Data("not JSON".utf8)
        defaults.set(corrupt, forKey: WebServiceStore.storageKey)
        let recovered = WebServiceStore(defaults: defaults, initialServices: [first])
        precondition(recovered.services == [first])
        precondition(defaults.data(forKey: WebServiceStore.storageKey + ".backup") == corrupt)
        print("OK: recuperación conserva los datos incompatibles")
    }
}
