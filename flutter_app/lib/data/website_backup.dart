import 'dart:convert';
import '../model/website.dart';

enum ImportMode { merge, replace }

class WebsiteBackup {
  WebsiteBackup._(List<Website> sites, this.selectedId)
    : websites = List.unmodifiable(sites);

  static const maxBytes = 1024 * 1024;
  static const maxWebsites = 1000;
  final List<Website> websites;
  final String? selectedId;

  static String encode(List<Website> sites, String? selectedId) {
    final text = const JsonEncoder.withIndent('  ').convert({
      'format': 'eduweb.websites',
      'version': 1,
      'websites': sites.map((site) => site.toJson()).toList(),
      'selectedId': selectedId,
    });
    // Una exportació ha de poder importar-se amb els mateixos límits.
    decode('$text\n');
    return '$text\n';
  }

  static WebsiteBackup decode(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('El fitxer supera el límit d’1 MB.');
    }
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('El fitxer no conté JSON vàlid.');
    }
    if (data is! Map<String, dynamic> || data['format'] != 'eduweb.websites') {
      throw const FormatException(
        'El fitxer no és una còpia de webs d’EduWeb.',
      );
    }
    if (data['version'] != 1) {
      throw const FormatException(
        'Esta versió de la còpia no és compatible amb EduWeb.',
      );
    }
    try {
      final entries = data['websites'] as List;
      if (entries.length > maxWebsites) {
        throw const FormatException('Massa webs.');
      }
      final sites = <Website>[];
      final ids = <String>{};
      for (final entry in entries) {
        final json = Map<String, dynamic>.from(entry as Map);
        final id = json['id'] as String;
        if (id.trim().isEmpty || !ids.add(id)) {
          throw const FormatException('Identificadors incorrectes.');
        }
        final hosts = json['allowedHosts'] ?? json['allowedHostSuffixes'];
        if (hosts != null &&
            (hosts is! List ||
                !hosts.every(
                  (host) =>
                      host is String &&
                      host.isNotEmpty &&
                      !RegExp(r'[\s/@?#]').hasMatch(host),
                ))) {
          throw const FormatException('Dominis incorrectes.');
        }
        sites.add(Website.fromJson(json));
      }
      final selected = data['selectedId'] as String?;
      return WebsiteBackup._(
        sites,
        ids.contains(selected) ? selected : sites.firstOrNull?.id,
      );
    } catch (_) {
      throw const FormatException(
        'La còpia conté webs o opcions no vàlides. No s’ha importat cap web.',
      );
    }
  }
}

class ImportResult {
  const ImportResult({required this.added, required this.skipped});
  final int added;
  final int skipped;
}
