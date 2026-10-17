# WhatsAppWrapper

Contenidor web original per a iOS/iPadOS, escrit en SwiftUI i WKWebView.
Va començar amb WhatsApp Web i es va adaptar després per a SnappyMail.

## EduWeb té repositori propi

L'aplicació genèrica **EduWeb**, amb Flutter per a Android, iPad i iPhone,
es desenvolupa en **[sasogu/EduWeb](https://github.com/sasogu/EduWeb)**.
Allí estan el codi actual, el README en valencià i les instruccions de compilació.
Per a continuar el desenvolupament d'EduWeb, utilitza eixe repositori.

## Contingut d'este repositori

- `WhatsAppWrapper/` i `WhatsAppWrapper.xcodeproj`: implementació SwiftUI.
- `tests/`: proves de la implementació SwiftUI.
- `flutter_app/`: còpia històrica de la migració a EduWeb 0.3.0;
  les actualitzacions de Flutter continuen en el repositori EduWeb.

Per a treballar amb SwiftUI, obri `WhatsAppWrapper.xcodeproj` en Xcode.
Les adreces locals es configuren en `Services.local.swift`, exclòs de Git,
seguint `Services.local.example.swift`.

## Llicència

MIT.
