import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ForEach(WebService.all) { service in
                ServiceView(service: service)
                    .tabItem {
                        Label(service.name, systemImage: service.systemImage)
                    }
            }
        }
    }
}

struct ServiceView: View {
    @State private var viewModel: WebViewModel

    init(service: WebService) {
        _viewModel = State(initialValue: WebViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ZStack {
                WebView(viewModel: viewModel)

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
