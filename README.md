# EduWeb

Les teues webs, juntes. Aplicació Flutter per a **Android, iPad i iPhone** que
reunix les webs que tries en pestanyes, amb la llista guardada en el dispositiu.
Interfície i documentació en valencià.

## Ús

1. Prem **Afig la primera web**, o el botó **+** si ja tens pestanyes.
2. Escriu un nom i una adreça, i tria una icona. Si omets el protocol, s'utilitza
   HTTPS. També admet HTTP, ports i adreces de la xarxa local.
3. Tria, si cal, **Vista d'escriptori** i si els enllaços externs s'han d'obrir en
   el navegador del sistema.
4. Canvia de web amb les pestanyes de la barra superior. En **Gestiona les webs**
   pots editar-les, eliminar-les i arrossegar-les per a canviar l'ordre.

Cada web disposa de navegació arrere i avant, inici, recàrrega i menú amb
**Neteja la memòria cau i recarrega** i **Obri en el navegador**. Els avisos i
les confirmacions JavaScript es mostren en pantalla; cap confirmació s'accepta
sense la resposta de l'usuari. En Android s'inclou el selector de fitxers per a
adjuntar documents des de les webs.

## Pantalla completa

Prem **Pantalla completa** en la barra superior per a ocultar la capçalera,
les pestanyes i els controls de navegació. La web continua oberta sense
recarregar-se. El botó flotant **Ix de pantalla completa** torna a mostrar els
controls; en Android també pots utilitzar el botó arrere per a eixir del mode.

## Exportar i importar les webs

En **Gestiona les webs**, prem **Importa o exporta** de la barra superior:

- **Exporta les webs** guarda un JSON amb els noms, les adreces, les icones,
  l'ordre, les opcions i la pestanya seleccionada.
- **Importa les webs** permet triar eixe fitxer des del dispositiu. Abans
  d'aplicar-lo, mostra quantes webs conté i demana com incorporar-les:
  **Combina** conserva les webs actuals i afig les noves sense duplicar adreces;
  **Substituïx** reemplaça tota la llista per la del fitxer.

El mateix format servix en Android i iOS. No inclou galetes, sessions ni
contrasenyes; cal iniciar sessió en el dispositiu de destinació. Si el fitxer és
incorrecte o incompatible, la llista actual es conserva. Límit: 1 MB i 1.000 webs.

## Memòria cau i sessions

La neteja esborra la memòria cau del visor i torna a crear la pestanya actual,
carregant de nou la seua adreça. Es conserven les galetes i l'emmagatzematge web.
Reinicia l'historial de navegació de la pestanya triada.

Les sessions i la memòria cau web es compartixen entre les pestanyes. Eliminar
una web de la llista no esborra la seua sessió ni les dades del servidor. Les
adreces i les preferències es guarden localment; EduWeb no té un servidor propi.
No s'omet la validació dels certificats HTTPS.

## Codi i requisits

- **Codi actual:** `flutter_app/`, Flutter 3.35.7+ i Dart 3.9.2+.
- **Android:** Android 7.0 / API 24 o posterior, SDK Android i Java 17+.
- **iOS:** iOS/iPadOS 17+, macOS i Xcode. L'app compilada per a iOS utilitza
  `WKWebView`; Android utilitza el visor web del sistema.
- **Versió anterior:** `WhatsAppWrapper/` i `WhatsAppWrapper.xcodeproj` conserven
  la implementació SwiftUI com a referència. El projecte Flutter d'iOS és
  `flutter_app/ios/Runner.xcworkspace`.

## Executar i compilar

Executa les ordres des de `flutter_app/`:

```sh
flutter pub get
flutter run
```

Per a compilar l'APK de producció, configura la signatura fora del repositori:

```sh
python3 tool/build_apk.py
```

El script utilitza la clau local d'EduWeb i la contrasenya guardada en `pass`;
només la passa a Gradle en la memòria del procés. El fitxer de clau, la seua
còpia de recuperació i les contrasenyes no es publiquen en el repositori.
Per a altres entorns es poden configurar `EDUWEB_KEYSTORE_PATH`,
`EDUWEB_STORE_PASSWORD` i `EDUWEB_KEY_PASSWORD` i executar:

```sh
flutter build apk --release --target-platform android-arm,android-arm64
```

L'APK es genera en `build/app/outputs/flutter-apk/app-release.apk` i és compatible
amb Android ARM de 32 i 64 bits. Per a desenvolupament pots utilitzar
`flutter build apk --debug` sense la signatura de producció.

En el Mac, obri `ios/Runner.xcworkspace`, tria l'equip de signatura i el dispositiu,
i executa l'aplicació. La compilació per a simulador no necessita signatura:

```sh
flutter build ios --simulator --debug
```

## Migració des de SwiftUI

Android comença sense webs predefinides. En iOS es manté l'identificador
`es.samuelsoriano.whatsapp-wrapper`. Si actualitzes l'app existent, sense
eliminar-la, s'importa la llista guardada per la versió SwiftUI en
`web-services.v1`, amb els noms, les adreces i les opcions de les pestanyes.
La configuració nova es guarda en les preferències de Flutter.

Les webs que només estaven definides en un fitxer Swift antic, sense haver
passat per la versió que guarda la llista, s'han d'afegir des de la interfície.
Les sessions no es transferixen entre Android i iOS. No inclogues adreces
privades en els fitxers de codi ni en captures públiques.

## Proves

```sh
flutter analyze
flutter test
flutter test integration_test/browser_test.dart -d IDENTIFICADOR_DEL_SIMULADOR
```

Les proves cobrixen la validació d'adreces i dominis, la importació del format
Swift, la persistència, les operacions consecutives, l'alta i l'edició de webs,
l'eliminació i els dissenys de mòbil i tauleta amb text ampliat. També cobrixen
l'exportació i importació, la combinació sense duplicats, les col·lisions
d'identificadors, la substitució, la cancel·lació i el rebuig de fitxers incorrectes.

La prova d'integració utilitza una web fictícia en un servidor local: comprova
les confirmacions, la navegació i el canvi de JavaScript després de netejar
la memòria cau, conservant una galeta de sessió. No accedix a correu real.

## Llicència

MIT. La icona vectorial d'EduWeb està en `flutter_app/assets/icon/eduweb.svg`.
