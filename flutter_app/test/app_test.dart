import 'package:eduweb/data/website_store.dart';
import 'package:eduweb/main.dart';
import 'package:eduweb/model/website.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Widget browser(Website site, bool active) =>
      Center(child: Text('Pàgina ${site.name}'));
  testWidgets('alta, validació i edició des de la interfície', (tester) async {
    final store = await WebsiteStore.load();
    await tester.pumpWidget(EduWebApp(store: store, browserBuilder: browser));
    await tester.tap(find.text('Afig la primera web'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('site-name')), 'Correu');
    await tester.enterText(
      find.byKey(const Key('site-address')),
      'javascript:alert(1)',
    );
    await tester.tap(find.text('Guarda'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP o HTTPS'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('site-address')),
      'mail.example.org',
    );
    await tester.tap(find.text('Guarda'));
    await tester.pumpAndSettle();
    expect(store.sites.single.name, 'Correu');
    expect(find.text('Pàgina Correu'), findsOneWidget);
    await tester.tap(find.byTooltip('Gestiona les webs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('site-name')), 'Nou nom');
    await tester.tap(find.text('Guarda'));
    await tester.pumpAndSettle();
    expect(store.sites.single.name, 'Nou nom');
    await tester.tap(find.byTooltip('Elimina Nou nom'));
    await tester.pumpAndSettle();
    expect(store.sites, isEmpty);
    await store.flush();
  });
  testWidgets(
    'pantalla completa conserva el visor i permet eixir i tornar arrere',
    (tester) async {
      final store = await WebsiteStore.load();
      store.save(Website.create(name: 'Correu', address: 'example.org'));
      var mounts = 0;
      await tester.pumpWidget(
        EduWebApp(
          store: store,
          browserBuilder: (_, _) => MountedBrowser(onMount: () => mounts++),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 1);
      await tester.tap(find.byTooltip('Pantalla completa'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Visor obert'), findsOneWidget);
      expect(mounts, 1);
      await tester.tap(find.byTooltip('Ix de pantalla completa'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ChoiceChip), findsOneWidget);
      expect(mounts, 1);
      await tester.tap(find.byTooltip('Pantalla completa'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(mounts, 1);
      await store.flush();
    },
  );
  testWidgets('sense desbordaments en mòbil, tauleta i text ampliat', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await WebsiteStore.load();
    for (var i = 0; i < 12; i++) {
      store.save(
        Website.create(
          id: '$i',
          name: 'Una web amb un nom llarg $i',
          address: 'example.org/$i',
        ),
      );
    }
    for (final size in [const Size(320, 640), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(EduWebApp(store: store, browserBuilder: browser));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Afig una web'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('site-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await store.flush();
  });
}

class MountedBrowser extends StatefulWidget {
  const MountedBrowser({super.key, required this.onMount});
  final VoidCallback onMount;
  @override
  State<MountedBrowser> createState() => _MountedBrowserState();
}

class _MountedBrowserState extends State<MountedBrowser> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Text('Visor obert');
}
