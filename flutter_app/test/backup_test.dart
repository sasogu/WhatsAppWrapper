import 'dart:convert';
import 'package:eduweb/data/website_backup.dart';
import 'package:eduweb/data/website_store.dart';
import 'package:eduweb/model/website.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Website site(String id, String address, {String? name, bool desktop = false}) =>
    Website.create(
      id: id,
      name: name ?? id,
      address: address,
      desktop: desktop,
      icon: 'envelope',
      externalLinks: true,
    );
WebsiteBackup backup(List<Website> sites, [String? selected]) =>
    WebsiteBackup.decode(
      WebsiteBackup.encode(sites, selected ?? sites.firstOrNull?.id),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('còpia portable conserva ordre, opcions i selecció, sense sessions', () {
    final original = [
      site('a', 'example.org:8445/#/inbox', name: 'Correu', desktop: true),
      site('b', 'http://example.net/'),
    ];
    final encoded = WebsiteBackup.encode(original, 'b');
    final decoded = WebsiteBackup.decode(encoded);
    expect(
      decoded.websites.map((s) => s.toJson()).toList(),
      original.map((s) => s.toJson()).toList(),
    );
    expect(decoded.selectedId, 'b');
    final data = jsonDecode(encoded) as Map;
    expect(data.keys.toSet(), {'format', 'version', 'websites', 'selectedId'});
    expect((data['websites'] as List).first.keys.toSet(), {
      'id',
      'name',
      'url',
      'icon',
      'desktop',
      'externalLinks',
      'allowedHosts',
    });
  });

  test('substitució persistent i còpia buida intencionada', () async {
    final store = await WebsiteStore.load();
    store.save(site('old', 'old.example.org'));
    store.importBackup(
      backup([site('b', 'example.net'), site('a', 'example.org')], 'a'),
      mode: ImportMode.replace,
    );
    await store.flush();
    var restored = await WebsiteStore.load();
    expect(restored.sites.map((s) => s.id), ['b', 'a']);
    expect(restored.selectedId, 'a');
    restored.importBackup(backup([]), mode: ImportMode.replace);
    await restored.flush();
    restored = await WebsiteStore.load();
    expect(restored.sites, isEmpty);
    expect(restored.selectedId, isNull);
  });

  test(
    'combinació preserva webs actuals i evita duplicats sense sobreescriure',
    () async {
      final store = await WebsiteStore.load();
      store.save(site('current', 'https://example.org', name: 'Actual'));
      final result = store.importBackup(
        backup([
          site('duplicate', 'https://example.org/', name: 'No substituir'),
          site('new', 'https://example.net'),
          site('repeated', 'https://example.net/'),
        ]),
        mode: ImportMode.merge,
      );
      expect(result.added, 1);
      expect(result.skipped, 2);
      expect(store.sites.map((s) => s.name), ['Actual', 'new']);
      expect(store.selectedId, 'current');
      await store.flush();
      expect((await WebsiteStore.load()).sites.length, 2);
    },
  );

  test(
    'col·lisió d’identificadors es resol sense perdre webs ni confondre pestanyes',
    () async {
      final store = await WebsiteStore.load();
      store.save(site('same', 'example.org'));
      store.importBackup(
        backup([site('same', 'example.net')]),
        mode: ImportMode.merge,
      );
      expect(store.sites.length, 2);
      expect(store.sites.last.id, isNot('same'));
      expect(store.sites.map((s) => s.id).toSet().length, 2);
      await store.flush();
      SharedPreferences.setMockInitialValues({});
      final empty = await WebsiteStore.load();
      empty.importBackup(
        backup([
          site('first', 'one.example.org'),
          site('chosen', 'two.example.org'),
        ], 'chosen'),
        mode: ImportMode.merge,
      );
      expect(empty.selectedId, 'chosen');
      await store.flush();
      await empty.flush();
    },
  );

  test('fitxers malformats no produïxen imports parcials', () async {
    final store = await WebsiteStore.load();
    store.save(site('original', 'example.org'));
    final bad =
        jsonDecode(
              WebsiteBackup.encode([
                site('good', 'good.example.org'),
                site('bad', 'bad.example.org'),
              ], 'good'),
            )
            as Map<String, dynamic>;
    (bad['websites'] as List).last['url'] = 'javascript:alert(1)';
    expect(
      () => store.importBackup(
        WebsiteBackup.decode(jsonEncode(bad)),
        mode: ImportMode.replace,
      ),
      throwsFormatException,
    );
    expect(store.sites.single.id, 'original');
    for (final value in [
      'not json',
      '[]',
      '{"version":1}',
      jsonEncode({...bad, 'version': 2}),
      jsonEncode({
        ...bad,
        'websites': [
          {
            'id': 'x',
            'name': 'X',
            'url': 'https://example.org',
            'allowedHosts': [42],
          },
        ],
      }),
      jsonEncode({
        ...bad,
        'websites': [
          site('x', 'example.org').toJson(),
          site('x', 'example.net').toJson(),
        ],
      }),
    ]) {
      expect(() => WebsiteBackup.decode(value), throwsFormatException);
    }
    await store.flush();
  });

  test('límits i selecció desconeguda', () {
    expect(
      () => WebsiteBackup.decode('x' * (WebsiteBackup.maxBytes + 1)),
      throwsFormatException,
    );
    final encoded =
        jsonDecode(WebsiteBackup.encode([site('a', 'example.org')], 'a'))
            as Map<String, dynamic>;
    encoded['selectedId'] = 'absent';
    expect(WebsiteBackup.decode(jsonEncode(encoded)).selectedId, 'a');
    encoded['websites'] = List.filled(
      WebsiteBackup.maxWebsites + 1,
      site('a', 'example.org').toJson(),
    );
    expect(
      () => WebsiteBackup.decode(jsonEncode(encoded)),
      throwsFormatException,
    );
  });
}
