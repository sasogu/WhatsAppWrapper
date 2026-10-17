import 'package:eduweb/data/website_backup.dart';
import 'package:eduweb/data/website_store.dart';
import 'package:eduweb/data/website_transfer_files.dart';
import 'package:eduweb/model/website.dart';
import 'package:eduweb/ui/website_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryFiles implements WebsiteTransferFiles {
  String? input;
  String? output;
  @override
  Future<String?> read() async => input;
  @override
  Future<bool> save(String content) async {
    output = content;
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<(WebsiteStore, MemoryFiles)> launch(WidgetTester tester) async {
    final store = await WebsiteStore.load();
    store.save(
      Website.create(id: 'current', name: 'Actual', address: 'example.org'),
    );
    final files = MemoryFiles();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ca'),
        supportedLocales: const [Locale('ca')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: WebsiteManager(store: store, files: files),
      ),
    );
    await tester.pumpAndSettle();
    return (store, files);
  }

  Future<void> choose(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('Importa o exporta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    // El diàleg espera la decisió de l’usuari amb l’operació pendent.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String incoming() => WebsiteBackup.encode([
    Website.create(id: 'new', name: 'Nova', address: 'example.net'),
  ], 'new');

  testWidgets('exporta la llista amb el selector de fitxers', (tester) async {
    final (store, files) = await launch(tester);
    await choose(tester, 'Exporta les webs');
    expect(WebsiteBackup.decode(files.output!).websites.single.name, 'Actual');
    expect(find.text('Còpia de webs exportada.'), findsOneWidget);
    await store.flush();
  });
  testWidgets('previsualitza, cancel·la i combina sense perdre la llista', (
    tester,
  ) async {
    final (store, files) = await launch(tester);
    files.input = incoming();
    await choose(tester, 'Importa les webs');
    expect(find.textContaining('El fitxer conté 1 webs'), findsOneWidget);
    expect(store.sites.length, 1);
    await tester.tap(find.text('Cancel·la'));
    await tester.pumpAndSettle();
    expect(store.sites.single.name, 'Actual');
    await choose(tester, 'Importa les webs');
    await tester.tap(find.text('Combina'));
    await tester.pumpAndSettle();
    expect(store.sites.map((s) => s.name), ['Actual', 'Nova']);
    await store.flush();
  });
  testWidgets('substitució explícita i error sense modificar dades', (
    tester,
  ) async {
    final (store, files) = await launch(tester);
    files.input = 'incorrecte';
    await choose(tester, 'Importa les webs');
    expect(store.sites.single.name, 'Actual');
    files.input = incoming();
    await choose(tester, 'Importa les webs');
    await tester.tap(find.text('Substituïx'));
    await tester.pumpAndSettle();
    expect(store.sites.single.name, 'Nova');
    expect(store.selectedId, 'new');
    files.input = null;
    await choose(tester, 'Importa les webs');
    expect(store.sites.single.name, 'Nova');
    await store.flush();
  });
}
