import SwiftUI

struct ContentView: View {
    @State private var selection = WebService.all.first?.id ?? ""

    var body: some View {
        TabView(selection: $selection) {
            ForEach(WebService.all) { service in
                ServiceView(service: service, onTwoFingerSwipe: switchTab)
                    .tabItem {
                        Label(service.name, systemImage: service.systemImage)
                    }
                    .tag(service.id)
            }
        }
    }

    private func switchTab(by offset: Int) {
        let services = WebService.all
        guard let index = services.firstIndex(where: { $0.id == selection }) else { return }
        let target = index + offset
        guard services.indices.contains(target) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation {
            selection = services[target].id
        }
    }
}

struct ServiceView: View {
    @State private var viewModel: WebViewModel
    let onTwoFingerSwipe: (Int) -> Void

    init(service: WebService, onTwoFingerSwipe: @escaping (Int) -> Void) {
        _viewModel = State(initialValue: WebViewModel(service: service))
        self.onTwoFingerSwipe = onTwoFingerSwipe
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ZStack {
                WebView(viewModel: viewModel, onTwoFingerSwipe: onTwoFingerSwipe)

                if let error = viewModel.error {
                    errorOverlay(error)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .disabled(!viewModel.canGoBack)
            .opacity(viewModel.canGoBack ? 1 : 0.3)

            if viewModel.isLoading {
                ProgressView(value: min(max(viewModel.estimatedProgress, 0.1), 0.9), total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            } else {
                Spacer()
            }

            Button {
                viewModel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func errorOverlay(_ error: WebViewModel.WebViewError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Error de conexion")
                .font(.headline)
            Text(error.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Reintentar") {
                viewModel.reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

#Preview {
    ContentView()
}
