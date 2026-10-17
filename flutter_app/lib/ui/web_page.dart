import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../model/website.dart';

class WebPage extends StatefulWidget {
  const WebPage({
    super.key,
    required this.site,
    required this.active,
    this.fullscreen = false,
  });
  final Website site;
  final bool active;
  final bool fullscreen;
  @override
  State<WebPage> createState() => WebPageState();
}

class WebPageState extends State<WebPage> {
  WebViewController? _controller;
  int _generation = 0;
  int _progress = 0;
  bool _back = false;
  bool _forward = false;
  bool _clearing = false;
  String? _error;
  Uri? _current;

  bool get _canShowDialog =>
      mounted && widget.active && ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    unawaited(_create(widget.site.url));
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _create(Uri url, {bool fresh = false}) async {
    final generation = ++_generation;
    bool valid() => mounted && generation == _generation;
    try {
      final PlatformWebViewControllerCreationParams params =
          WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
            )
          : const PlatformWebViewControllerCreationParams();
      final controller = WebViewController.fromPlatformCreationParams(params);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (widget.site.desktop) {
        final agent = defaultTargetPlatform == TargetPlatform.android
            ? 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
            : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';
        await controller.setUserAgent(agent);
      }
      if (controller.platform case final AndroidWebViewController android) {
        await AndroidWebViewController.enableDebugging(kDebugMode);
        await android.setOnShowFileSelector((params) async {
          if (!_canShowDialog) return [];
          final files = await FilePicker.platform.pickFiles(
            allowMultiple: params.mode == FileSelectorMode.openMultiple,
          );
          return files?.paths
                  .whereType<String>()
                  .map((path) => Uri.file(path).toString())
                  .toList() ??
              [];
        });
      }
      if (controller.platform case final WebKitWebViewController webkit) {
        await webkit.setAllowsBackForwardNavigationGestures(true);
        await webkit.setInspectable(kDebugMode);
      }
      await controller.setOnJavaScriptAlertDialog((request) async {
        if (!valid() || !_canShowDialog) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(widget.site.name),
            content: Text(request.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('D’acord'),
              ),
            ],
          ),
        );
      });
      await controller.setOnJavaScriptConfirmDialog((request) async {
        if (!valid() || !_canShowDialog) return false;
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(widget.site.name),
                content: Text(request.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel·la'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Accepta'),
                  ),
                ],
              ),
            ) ??
            false;
      });
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (valid()) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (valid()) {
              setState(() {
                _progress = 0;
                _error = null;
              });
            }
          },
          onPageFinished: (_) async {
            final back = await controller.canGoBack();
            final forward = await controller.canGoForward();
            if (valid()) {
              setState(() {
                _back = back;
                _forward = forward;
                _progress = 100;
              });
            }
          },
          onUrlChange: (change) {
            if (valid() && change.url != null) {
              _current = Uri.tryParse(change.url!);
            }
          },
          onWebResourceError: (error) {
            if (valid() && error.isForMainFrame == true) {
              setState(() {
                _error =
                    'No s’ha pogut carregar la web. Comprova l’adreça i la connexió.';
                _progress = 100;
              });
            }
          },
          onNavigationRequest: (request) async {
            if (!valid()) return NavigationDecision.prevent;
            final target = Uri.tryParse(request.url);
            if (target == null) return NavigationDecision.prevent;
            if (['http', 'https'].contains(target.scheme)) {
              if (request.isMainFrame &&
                  widget.site.externalLinks &&
                  !widget.site.allowsHost(target.host)) {
                if (widget.active) await _openExternal(target);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }
            if (['about', 'data', 'blob'].contains(target.scheme)) {
              return NavigationDecision.navigate;
            }
            if (widget.active &&
                [
                  'mailto',
                  'tel',
                  'sms',
                  'facetime',
                  'facetime-audio',
                ].contains(target.scheme)) {
              await _openExternal(target);
            }
            return NavigationDecision.prevent;
          },
        ),
      );
      if (!valid()) return;
      setState(() {
        _controller = controller;
        _current = url;
        _error = null;
        _clearing = false;
        _progress = 0;
      });
      await controller.loadRequest(
        url,
        headers: fresh
            ? const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}
            : const {},
      );
    } catch (_) {
      if (valid()) {
        setState(() {
          _error = 'No s’ha pogut obrir el visor web. Torna a intentar-ho.';
          _clearing = false;
          _progress = 100;
        });
      }
    }
  }

  Future<void> _openExternal(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Missatge genèric: no registrar URL ni dades de la pàgina. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No s’ha pogut obrir l’enllaç.')),
      );
    }
  }

  Future<void> clearCache() async {
    final controller = _controller;
    if (_clearing || controller == null) return;
    final target = _current ?? widget.site.url;
    setState(() {
      _clearing = true;
      _error = null;
    });
    try {
      await controller.clearCache();
      if (!mounted) return;
      _generation++;
      setState(() {
        _controller = null;
        _back = false;
        _forward = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) await _create(target, fresh: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _clearing = false;
          _error = 'No s’ha pogut netejar la memòria cau. Torna a intentar-ho.';
        });
      }
    }
  }

  Future<void> _reload() async {
    if (_controller == null || _error != null) {
      await _create(_current ?? widget.site.url);
    } else {
      await _controller!.reload();
    }
  }

  @visibleForTesting
  Future<Object> evaluate(String script) =>
      _controller!.runJavaScriptReturningResult(script);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.fullscreen && (!_back || !widget.active),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _back && !widget.fullscreen) {
        unawaited(_controller?.goBack());
      }
    },
    child: Column(
      children: [
        if (!widget.fullscreen && (_progress < 100 || _clearing))
          LinearProgressIndicator(value: _clearing ? null : _progress / 100),
        Expanded(
          child: Stack(
            children: [
              if (_controller != null)
                Positioned.fill(
                  child: WebViewWidget(
                    key: ValueKey(_generation),
                    controller: _controller!,
                  ),
                ),
              if (_clearing || _controller == null && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_outlined, size: 48),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _reload,
                              child: const Text('Torna a intentar-ho'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!widget.fullscreen)
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Arrere',
                  onPressed: _back && !_clearing
                      ? () => _controller?.goBack()
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  tooltip: 'Avant',
                  onPressed: _forward && !_clearing
                      ? () => _controller?.goForward()
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  tooltip: 'Inici',
                  onPressed: !_clearing && _controller != null
                      ? () => _controller!.loadRequest(widget.site.url)
                      : null,
                  icon: const Icon(Icons.home_outlined),
                ),
                IconButton(
                  tooltip: 'Recarrega',
                  onPressed: _clearing ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Més opcions',
                  enabled: !_clearing,
                  onSelected: (action) {
                    if (action == 'cache') unawaited(clearCache());
                    if (action == 'external') {
                      unawaited(_openExternal(_current ?? widget.site.url));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'cache',
                      child: Text('Neteja la memòria cau i recarrega'),
                    ),
                    PopupMenuItem(
                      value: 'external',
                      child: Text('Obri en el navegador'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
