import SwiftUI

struct ContentView: View {
    @State private var store = WebServiceStore.applicationStore()
    @AppStorage("selected-web-service") private var selection = ""
    @State private var showingManager = false
    @State private var newWeb: WebEditorRoute?

    var body: some View {
        Group {
            if store.services.isEmpty {
                ContentUnavailableView {
                    Label("Tus webs, en un solo lugar", systemImage: "globe")
                } description: {
                    Text("Añade tus webs y abre cada una en su propia pestaña.")
                } actions: {
                    Button("Añadir web", systemImage: "plus") { newWeb = .new }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("start-add-web")
                }
            } else {
                TabView(selection: $selection) {
                    ForEach(store.services) { service in
                        ServiceView(service: service, onTwoFingerSwipe: switchTab,
                                    onManage: { showingManager = true })
                            .id(service)
                            .tabItem { Label(service.name, systemImage: service.systemImage) }
                            .tag(service.id)
                    }
                }
            }
        }
        .onAppear(perform: ensureSelection)
        .onChange(of: store.services) { _, _ in ensureSelection() }
        .sheet(isPresented: $showingManager) {
            WebServicesManager(store: store) { selection = $0 }
        }
        .sheet(item: $newWeb) { _ in
            WebServiceEditor(service: nil) { service in
                store.save(service)
                selection = service.id
            }
        }
    }

    private func ensureSelection() {
        if !store.services.contains(where: { $0.id == selection }) {
            selection = store.services.first?.id ?? ""
        }
    }

    private func switchTab(by offset: Int) {
        guard let index = store.services.firstIndex(where: { $0.id == selection }) else { return }
        let target = index + offset
        guard store.services.indices.contains(target) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { selection = store.services[target].id }
    }
}

private enum WebEditorRoute: Identifiable {
    case new, edit(WebService)
    var id: String {
        switch self {
        case .new: "new"
        case .edit(let service): service.id
        }
    }
    var service: WebService? {
        if case .edit(let service) = self { return service }
        return nil
    }
}

struct WebServicesManager: View {
    let store: WebServiceStore
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editor: WebEditorRoute?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.services) { service in
                        Button { editor = .edit(service) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: service.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(service.name).foregroundStyle(.primary)
                                    Text(service.url.host ?? "")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil").foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { store.remove(at: $0) }
                    .onMove { store.move(from: $0, to: $1) }
                    Button("Añadir web", systemImage: "plus") { editor = .new }
                        .accessibilityIdentifier("add-web")
                } footer: {
                    Text("Toca una web para editarla. Pulsa Editar para ordenar o eliminar pestañas. Tus sesiones se conservan al eliminar una pestaña.")
                }
            }
            .navigationTitle("EduWeb")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton().accessibilityIdentifier("edit-web-services")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Hecho") { dismiss() } }
            }
            .sheet(item: $editor) { route in
                WebServiceEditor(service: route.service) { service in
                    store.save(service)
                    onSelect(service.id)
                }
            }
        }
    }
}

struct WebServiceEditor: View {
    let service: WebService?
    let onSave: (WebService) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var address: String
    @State private var icon: String
    @State private var desktop: Bool
    @State private var externalLinks: Bool
    @State private var validationMessage: String?
    private let icons = ["globe", "envelope", "message", "checklist", "newspaper", "calendar", "book", "star"]

    init(service: WebService?, onSave: @escaping (WebService) -> Void) {
        self.service = service
        self.onSave = onSave
        _name = State(initialValue: service?.name ?? "")
        _address = State(initialValue: service?.url.absoluteString ?? "")
        _icon = State(initialValue: service?.systemImage ?? "globe")
        _desktop = State(initialValue: service?.prefersDesktop ?? false)
        _externalLinks = State(initialValue: service?.opensExternalLinksInBrowser ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Web") {
                    TextField("Nombre", text: $name)
                        .accessibilityIdentifier("web-name")
                    TextField("Dirección web", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("web-address")
                    Picker("Icono", selection: $icon) {
                        ForEach(icons, id: \.self) { image in
                            Image(systemName: image).tag(image)
                        }
                        if !icons.contains(icon) { Image(systemName: icon).tag(icon) }
                    }
                }
                Section {
                    Toggle("Vista de escritorio", isOn: $desktop)
                    Toggle("Abrir enlaces externos en Safari", isOn: $externalLinks)
                } footer: {
                    Text("Si omites el protocolo de la dirección, se usará HTTPS. Activa la vista de escritorio si la web la necesita.")
                }
            }
            .navigationTitle(service == nil ? "Añadir web" : "Editar web")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.isEmpty)
                }
            }
            .alert("Revisa la web", isPresented: Binding(
                get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } }
            )) {
                Button("Aceptar", role: .cancel) { validationMessage = nil }
            } message: { Text(validationMessage ?? "") }
        }
    }

    private func save() {
        do {
            let saved = try WebService.validated(id: service?.id ?? UUID().uuidString,
                                                name: name, address: address, systemImage: icon,
                                                prefersDesktop: desktop,
                                                opensExternalLinksInBrowser: externalLinks)
            onSave(saved)
            dismiss()
        } catch { validationMessage = error.localizedDescription }
    }
}

struct ServiceView: View {
    @State private var viewModel: WebViewModel
    let onTwoFingerSwipe: (Int) -> Void
    let onManage: () -> Void
    @Environment(\.openURL) private var openURL

    init(service: WebService, onTwoFingerSwipe: @escaping (Int) -> Void, onManage: @escaping () -> Void) {
        _viewModel = State(initialValue: WebViewModel(service: service))
        self.onTwoFingerSwipe = onTwoFingerSwipe
        self.onManage = onManage
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if viewModel.isLoading || viewModel.isClearingCache {
                ProgressView(value: min(max(viewModel.estimatedProgress, 0.1), 0.95))
                    .progressViewStyle(.linear)
            }
            ZStack {
                WebView(viewModel: viewModel, onTwoFingerSwipe: onTwoFingerSwipe)
                    .id(viewModel.webViewID)
                    .allowsHitTesting(!viewModel.isClearingCache)
                if let error = viewModel.error { errorOverlay(error) }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { viewModel.goBack() } label: { Image(systemName: "chevron.left").frame(width: 32, height: 36) }
                .accessibilityLabel("Atrás")
                .disabled(!viewModel.canGoBack || viewModel.isClearingCache)
            Button { viewModel.goForward() } label: { Image(systemName: "chevron.right").frame(width: 32, height: 36) }
                .accessibilityLabel("Adelante")
                .disabled(!viewModel.canGoForward || viewModel.isClearingCache)
            Text(viewModel.isClearingCache ? "Limpiando caché…" : viewModel.service.name)
                .font(.subheadline.weight(.semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise").frame(width: 32, height: 36) }
                .accessibilityLabel("Recargar")
                .disabled(viewModel.isClearingCache)
            Menu {
                Button("Ir al inicio", systemImage: "house") { viewModel.goHome() }
                Button("Abrir en Safari", systemImage: "safari") {
                    openURL(viewModel.webView?.url ?? viewModel.service.url)
                }
                Button("Limpiar caché y recargar", systemImage: "arrow.clockwise.circle") { viewModel.clearCacheAndReload() }
                Divider()
                Button("Gestionar webs", systemImage: "slider.horizontal.3", action: onManage)
            } label: { Image(systemName: "ellipsis.circle").frame(width: 32, height: 36) }
                .accessibilityLabel("Más opciones")
                .disabled(viewModel.isClearingCache)
            Button(action: onManage) { Image(systemName: "square.grid.2x2").frame(width: 32, height: 36) }
                .accessibilityLabel("Gestionar webs")
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.bar)
    }

    private func errorOverlay(_ error: WebViewModel.WebViewError) -> some View {
        ContentUnavailableView {
            Label("No se pudo cargar la web", systemImage: "wifi.slash")
        } description: { Text(error.message) } actions: {
            Button("Reintentar") { viewModel.reload() }.buttonStyle(.borderedProminent)
        }
    }
}

#Preview { ContentView() }
