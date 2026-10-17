import 'dart:convert';
import 'package:eduweb/data/website_store.dart';
import 'package:eduweb/model/website.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'alta, edició, ordenació, selecció i llista buida persistents',
    () async {
      final store = await WebsiteStore.load();
      final a = Website.create(id: 'a', name: 'A', address: 'example.org');
      final b = Website.create(id: 'b', name: 'B', address: 'example.net');
      store.save(a);
      store.save(b);
      store.select('a');
      store.save(
        Website.create(
          id: 'a',
          name: 'Canviada',
          address: 'example.org/changed',
        ),
      );
      store.reorder(0, 2);
      await store.flush();
      var loaded = await WebsiteStore.load();
      expect(loaded.sites.map((s) => s.id), ['b', 'a']);
      expect(loaded.selectedId, 'a');
      expect(loaded.sites.last.name, 'Canviada');
      loaded.remove('a');
      expect(loaded.selectedId, 'b');
      loaded.remove('b');
      await loaded.flush();
      loaded = await WebsiteStore.load();
      expect(loaded.sites, isEmpty);
      expect(loaded.selectedId, isNull);
    },
  );
  test(
    'importació iOS una sola vegada i dades incompatibles preservades',
    () async {
      var calls = 0;
      final store = await WebsiteStore.load(
        legacyReader: () async {
          calls++;
          return {
            'websites': jsonEncode([
              {
                'id': 'old',
                'name': 'Antiga',
                'url': 'https://example.org',
                'prefersDesktop': true,
                'opensExternalLinksInBrowser': true,
              },
            ]),
            'selectedId': 'old',
          };
        },
      );
      expect(store.selected!.desktop, isTrue);
      store.remove('old');
      await store.flush();
      final loaded = await WebsiteStore.load(
        legacyReader: () async {
          calls++;
          return null;
        },
      );
      expect(loaded.sites, isEmpty);
      expect(calls, 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(WebsiteStore.storageKey, 'incompatible');
      expect((await WebsiteStore.load()).sites, isEmpty);
      expect(
        prefs.getString('${WebsiteStore.storageKey}.backup'),
        'incompatible',
      );
    },
  );
  test('operacions consecutives guarden l’últim estat', () async {
    final store = await WebsiteStore.load();
    for (var i = 0; i < 20; i++) {
      store.save(
        Website.create(id: '$i', name: 'Web $i', address: 'example.org/$i'),
      );
    }
    store.select('5');
    await store.flush();
    final loaded = await WebsiteStore.load();
    expect(loaded.sites.length, 20);
    expect(loaded.selectedId, '5');
  });
}
