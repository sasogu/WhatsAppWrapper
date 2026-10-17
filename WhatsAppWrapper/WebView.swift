import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let viewModel: WebViewModel
    /// Recibe -1 (pestaña anterior) o +1 (siguiente) al deslizar con dos dedos.
    var onTwoFingerSwipe: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onTwoFingerSwipe: onTwoFingerSwipe)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        if viewModel.service.prefersDesktop {
            config.defaultWebpagePreferences.preferredContentMode = .desktop
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        if viewModel.service.prefersDesktop {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        }
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        webView.isInspectable = true
        #endif

        viewModel.webView = webView

        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerSwipe(_:)))
            swipe.direction = direction
            swipe.numberOfTouchesRequired = 2
            swipe.delegate = context.coordinator
            webView.addGestureRecognizer(swipe)
        }

        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)

        viewModel.loadInitialURL()

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onTwoFingerSwipe = onTwoFingerSwipe
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        uiView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.isLoading))
        uiView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.canGoBack))
        uiView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.canGoForward))
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        coordinator.cancelDialog()
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
        let viewModel: WebViewModel
        var onTwoFingerSwipe: (Int) -> Void
        private weak var activeDialog: UIAlertController?
        private var pendingDialogCancellation: (() -> Void)?

        init(viewModel: WebViewModel, onTwoFingerSwipe: @escaping (Int) -> Void) {
            self.viewModel = viewModel
            self.onTwoFingerSwipe = onTwoFingerSwipe
        }

        @objc func handleTwoFingerSwipe(_ gesture: UISwipeGestureRecognizer) {
            onTwoFingerSwipe(gesture.direction == .left ? 1 : -1)
        }

        // El deslizamiento convive con el scroll y el zoom de la página.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            DispatchQueue.main.async { [weak self, weak webView] in
                guard let self, let webView, self.viewModel.webView === webView else { return }
                switch keyPath {
                case "estimatedProgress":
                    self.viewModel.estimatedProgress = webView.estimatedProgress
                case "isLoading":
                    self.viewModel.isLoading = webView.isLoading
                case "canGoBack":
                    self.viewModel.canGoBack = webView.canGoBack
                case "canGoForward":
                    self.viewModel.canGoForward = webView.canGoForward
                default:
                    break
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if ["http", "https"].contains(scheme) {
                let external = !viewModel.service.allowsHost(url.host ?? "")
                if external && viewModel.service.opensExternalLinksInBrowser
                    && navigationAction.navigationType == .linkActivated
                    && navigationAction.targetFrame?.isMainFrame != false {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                } else {
                    decisionHandler(.allow)
                }
                return
            }
            if ["about", "blob", "data"].contains(scheme) {
                decisionHandler(.allow)
                return
            }
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            guard viewModel.webView === webView else { return }
            viewModel.error = WebViewModel.WebViewError(message: error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard viewModel.webView === webView else { return }
            viewModel.error = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            self.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard viewModel.webView === webView else { return }
            viewModel.error = WebViewModel.WebViewError(message: "La web se ha detenido. Pulsa Reintentar para volver a cargarla.")
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: viewModel.service.name, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { [weak self] _ in
                self?.pendingDialogCancellation = nil
                completionHandler()
            })
            present(alert, from: webView, onCancel: completionHandler)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: viewModel.service.name, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { [weak self] _ in
                self?.pendingDialogCancellation = nil
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { [weak self] _ in
                self?.pendingDialogCancellation = nil
                completionHandler(true)
            })
            present(alert, from: webView, onCancel: { completionHandler(false) })
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: viewModel.service.name, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { [weak self] _ in
                self?.pendingDialogCancellation = nil
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { [weak self, weak alert] _ in
                self?.pendingDialogCancellation = nil
                completionHandler(alert?.textFields?.first?.text)
            })
            present(alert, from: webView, onCancel: { completionHandler(nil) })
        }

        private func present(_ alert: UIAlertController, from webView: WKWebView, onCancel: @escaping () -> Void) {
            guard var controller = webView.window?.rootViewController else { onCancel(); return }
            while let presented = controller.presentedViewController { controller = presented }
            guard controller.viewIfLoaded?.window != nil, !(controller is UIAlertController) else { onCancel(); return }
            activeDialog = alert
            pendingDialogCancellation = onCancel
            controller.present(alert, animated: true)
        }

        func cancelDialog() {
            let completion = pendingDialogCancellation
            pendingDialogCancellation = nil
            activeDialog?.dismiss(animated: false)
            completion?()
        }
    }
}
