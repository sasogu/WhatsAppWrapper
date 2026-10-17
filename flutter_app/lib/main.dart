import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/website_store.dart';
import 'model/website.dart';
import 'ui/site_icons.dart';
import 'ui/web_page.dart';
import 'ui/website_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EduWebBootstrap());
}

class EduWebBootstrap extends StatefulWidget {
  const EduWebBootstrap({super.key});
  @override
  State<EduWebBootstrap> createState() => _EduWebBootstrapState();
}

class _EduWebBootstrapState extends State<EduWebBootstrap> {
  late Future<WebsiteStore> _store = WebsiteStore.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<WebsiteStore>(
    future: _store,
    builder: (context, snapshot) {
      if (snapshot.hasData) return EduWebApp(store: snapshot.data!);
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? FilledButton(
                    onPressed: () =>
                        setState(() => _store = WebsiteStore.load()),
                    child: const Text('Torna a intentar-ho'),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

typedef BrowserBuilder = Widget Function(Website site, bool active);

class EduWebApp extends StatelessWidget {
  const EduWebApp({super.key, required this.store, this.browserBuilder});
  final WebsiteStore store;
  final BrowserBuilder? browserBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EduWeb',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ca'),
    supportedLocales: const [Locale('ca')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B65)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF58C5B3),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: EduWebHome(store: store, browserBuilder: browserBuilder),
  );
}

class EduWebHome extends StatefulWidget {
  const EduWebHome({super.key, required this.store, this.browserBuilder});
  final WebsiteStore store;
  final BrowserBuilder? browserBuilder;
  @override
  State<EduWebHome> createState() => _EduWebHomeState();
}

class _EduWebHomeState extends State<EduWebHome> {
  final _visited = <String>{};
  bool _fullscreen = false;

  void _setFullscreen(bool value) => setState(() => _fullscreen = value);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      if (store.selectedId != null) _visited.add(store.selectedId!);
      final sites = store.sites;
      final selected = sites.indexWhere((s) => s.id == store.selectedId);
      return PopScope(
        canPop: !_fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _fullscreen) _setFullscreen(false);
        },
        child: Scaffold(
          appBar: _fullscreen
              ? null
              : AppBar(
                  title: const Text('EduWeb'),
                  actions: [
                    if (sites.isNotEmpty)
                      IconButton(
                        tooltip: 'Pantalla completa',
                        onPressed: () => _setFullscreen(true),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    IconButton(
                      tooltip: 'Afig una web',
                      onPressed: () => editWebsite(context, store),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Gestiona les webs',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => WebsiteManager(store: store),
                        ),
                      ),
                      icon: const Icon(Icons.grid_view_outlined),
                    ),
                  ],
                ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (!_fullscreen && store.saveError != null)
                    MaterialBanner(
                      content: Text(store.saveError!),
                      actions: [
                        TextButton(
                          onPressed: store.retrySave,
                          child: const Text('Reintenta'),
                        ),
                      ],
                    ),
                  if (!_fullscreen && sites.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: sites
                              .map(
                                (site) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: ValueKey('tab-${site.id}'),
                                    avatar: Icon(siteIcon(site.icon), size: 18),
                                    label: Text(site.name),
                                    selected: site.id == store.selectedId,
                                    onSelected: (_) => store.select(site.id),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: sites.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.language,
                                    size: 72,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Les teues webs, juntes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Afig les webs que utilitzes i obri cada una en la seua pestanya.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        editWebsite(context, store),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Afig la primera web'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : IndexedStack(
                            index: selected < 0 ? 0 : selected,
                            children: sites.map((site) {
                              if (!_visited.contains(site.id)) {
                                return SizedBox.shrink(key: ValueKey(site.id));
                              }
                              final active = site.id == store.selectedId;
                              return KeyedSubtree(
                                key: ValueKey(site.browserIdentity),
                                child:
                                    widget.browserBuilder?.call(site, active) ??
                                    WebPage(
                                      site: site,
                                      active: active,
                                      fullscreen: _fullscreen,
                                    ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
              if (_fullscreen)
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Ix de pantalla completa',
                        onPressed: () => _setFullscreen(false),
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
