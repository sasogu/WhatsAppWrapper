import 'dart:io';
import 'package:eduweb/data/website_store.dart';
import 'package:eduweb/main.dart';
import 'package:eduweb/model/website.dart';
import 'package:eduweb/ui/web_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'visor real: confirmació, navegació i memòria cau amb sessió persistent',
    (tester) async {
      var version = 1;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final asset = request.uri.path == '/asset.js';
        request.response.headers.contentType = asset
            ? ContentType('application', 'javascript', charset: 'utf-8')
            : ContentType.html;
        request.response.headers.set(
          'Cache-Control',
          asset ? 'public, max-age=3600' : 'no-store',
        );
        request.response.write(
          asset
              ? 'document.getElementById("content").textContent="Contingut $version";'
              : '''
<!doctype html><html><meta name="viewport" content="width=device-width"><body>
<h1 id="content"></h1><p id="session"></p><p id="result"></p>
<button id="confirm" onclick="document.getElementById('result').textContent=confirm('Confirmació de prova')?'acceptat':'cancel·lat'">Confirma</button>
<a id="next" href="/next">Següent</a>
<script>document.getElementById('session').textContent=document.cookie.includes('eduwebTestSession=kept')?'conservada':'nova';document.cookie='eduwebTestSession=kept;path=/';</script><script src="/asset.js"></script></body></html>''',
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      SharedPreferences.setMockInitialValues({});
      final store = await WebsiteStore.load(legacyReader: () async => null);
      store.save(
        Website.create(
          id: 'fixture',
          name: 'Prova',
          address: 'http://127.0.0.1:${server.port}/',
        ),
      );
      await store.flush();
      await tester.pumpWidget(EduWebApp(store: store));
      await tester.pump();
      Future<void> waitFor(String script, String text) async {
        final limit = DateTime.now().add(const Duration(seconds: 30));
        while (DateTime.now().isBefore(limit)) {
          await tester.pump(const Duration(milliseconds: 200));
          try {
            final state = tester.state<WebPageState>(find.byType(WebPage));
            if ((await state.evaluate(script)).toString().contains(text)) {
              return;
            }
          } catch (_) {}
        }
        fail('La web de prova no ha arribat a l’estat esperat.');
      }

      const content = 'document.getElementById("content")?.textContent || ""';
      await waitFor(content, 'Contingut 1');
      var state = tester.state<WebPageState>(find.byType(WebPage));
      await state.evaluate(
        'setTimeout(()=>document.getElementById("confirm").click(),0);true',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel·la'));
      await tester.pumpAndSettle();
      await waitFor(
        'document.getElementById("result").textContent',
        'cancel·lat',
      );
      await state.evaluate(
        'setTimeout(()=>document.getElementById("confirm").click(),0);true',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepta'));
      await tester.pumpAndSettle();
      await waitFor(
        'document.getElementById("result").textContent',
        'acceptat',
      );
      version = 2;
      await tester.tap(find.byTooltip('Més opcions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neteja la memòria cau i recarrega'));
      await waitFor(content, 'Contingut 2');
      state = tester.state<WebPageState>(find.byType(WebPage));
      expect(
        (await state.evaluate(
          'document.getElementById("session").textContent',
        )).toString(),
        contains('conservada'),
      );
      await state.evaluate('document.getElementById("next").click();true');
      await waitFor('location.pathname', '/next');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Arrere'));
      await waitFor('location.pathname === "/"', 'true');
      expect(tester.takeException(), isNull);
    },
  );
}
