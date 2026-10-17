import 'package:eduweb/model/website.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTPS automàtic, HTTP, port i fragment', () {
    final site = Website.create(
      name: ' Correu ',
      address: 'example.org:8445/#/mailbox/INBOX',
    );
    expect(site.name, 'Correu');
    expect(site.url.scheme, 'https');
    expect(site.url.port, 8445);
    expect(site.url.fragment, '/mailbox/INBOX');
    expect(Website.parseAddress('http://[::1]:8080/').host, '::1');
    expect(Website.parseAddress('localhost:8080/').host, 'localhost');
  });
  test('rebutja protocols, credencials, espais i ports incorrectes', () {
    for (final address in [
      '',
      'https://',
      'javascript:alert(1)',
      'javascript://example.org',
      'file:/tmp/a',
      'file:///tmp/a',
      'mailto:a@example.org',
      'https://user:fake@example.org',
      'https://exa mple.org',
      'https://example.org:99999',
    ]) {
      expect(() => Website.parseAddress(address), throwsFormatException);
    }
    expect(
      () => Website.create(name: '  ', address: 'example.org'),
      throwsFormatException,
    );
  });
  test('dominis delimitats i compatibilitat amb dades Swift', () {
    final site = Website.fromJson({
      'id': 'old',
      'name': 'Missatges',
      'url': 'https://web.whatsapp.com',
      'systemImage': 'message',
      'prefersDesktop': true,
      'opensExternalLinksInBrowser': true,
      'allowedHostSuffixes': ['whatsapp.com', 'whatsapp.net'],
    });
    expect(site.desktop, isTrue);
    expect(site.externalLinks, isTrue);
    expect(site.allowsHost('media.whatsapp.net'), isTrue);
    expect(site.allowsHost('evilwhatsapp.com'), isFalse);
    expect(site.allowsHost('whatsapp.com.example.org'), isFalse);
    expect(Website.fromJson(site.toJson()).toJson(), site.toJson());
  });
}
