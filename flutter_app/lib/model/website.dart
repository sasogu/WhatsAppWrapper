import 'dart:math';

class Website {
  const Website({
    required this.id,
    required this.name,
    required this.url,
    this.icon = 'globe',
    this.desktop = false,
    this.externalLinks = false,
    this.allowedHosts = const [],
  });

  final String id;
  final String name;
  final Uri url;
  final String icon;
  final bool desktop;
  final bool externalLinks;
  final List<String> allowedHosts;

  factory Website.create({
    String? id,
    required String name,
    required String address,
    String icon = 'globe',
    bool desktop = false,
    bool externalLinks = false,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Escriu un nom per a la web.');
    }
    final url = parseAddress(address);
    return Website(
      id:
          id ??
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      name: trimmedName,
      url: url,
      icon: icon,
      desktop: desktop,
      externalLinks: externalLinks,
      allowedHosts: url.host == 'web.whatsapp.com'
          ? const ['whatsapp.com', 'whatsapp.net', 'fbcdn.net']
          : [url.host],
    );
  }

  static Uri parseAddress(String address) {
    const message =
        'Introduïx una adreça HTTP o HTTPS vàlida, sense espais ni credencials.';
    final text = address.trim();
    if (text.isEmpty || RegExp(r'\s').hasMatch(text)) {
      throw const FormatException(message);
    }
    final separator = text.contains('://');
    final hostAndPort = RegExp(
      r'^[a-zA-Z0-9.-]+:[0-9]+([/?#]|$)',
    ).hasMatch(text);
    if (!separator &&
        !hostAndPort &&
        RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(text)) {
      throw const FormatException(message);
    }
    try {
      final uri = Uri.parse(separator ? text : 'https://$text');
      if (!['http', 'https'].contains(uri.scheme) ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.port < 1 ||
          uri.port > 65535) {
        throw const FormatException(message);
      }
      return uri;
    } on FormatException {
      throw const FormatException(message);
    }
  }

  bool allowsHost(String host) {
    final normalized = host.toLowerCase();
    return (allowedHosts.isEmpty ? [url.host] : allowedHosts).any((allowed) {
      final suffix = allowed.toLowerCase();
      return normalized == suffix || normalized.endsWith('.$suffix');
    });
  }

  // Canviar el nom o la icona no reinicia el visor ni la pàgina oberta.
  String get browserIdentity => '$id|$url|$desktop|$externalLinks';

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url.toString(),
    'icon': icon,
    'desktop': desktop,
    'externalLinks': externalLinks,
    'allowedHosts': allowedHosts,
  };

  factory Website.fromJson(Map<String, dynamic> json) {
    final site = Website.create(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['url'] as String,
      icon: (json['icon'] ?? json['systemImage'] ?? 'globe') as String,
      desktop: (json['desktop'] ?? json['prefersDesktop'] ?? false) as bool,
      externalLinks:
          (json['externalLinks'] ??
                  json['opensExternalLinksInBrowser'] ??
                  false)
              as bool,
    );
    final hosts =
        (json['allowedHosts'] ?? json['allowedHostSuffixes']) as List?;
    if (hosts == null) return site;
    return Website(
      id: site.id,
      name: site.name,
      url: site.url,
      icon: site.icon,
      desktop: site.desktop,
      externalLinks: site.externalLinks,
      allowedHosts: hosts.cast<String>(),
    );
  }
}
