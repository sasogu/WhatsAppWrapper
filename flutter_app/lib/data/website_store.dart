import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/website.dart';
import 'website_backup.dart';

typedef LegacyReader = Future<Map<String, dynamic>?> Function();

class WebsiteStore extends ChangeNotifier {
  WebsiteStore._(this._preferences, this._sites, this._selectedId);

  static const storageKey = 'eduweb.websites.v1';
  final SharedPreferences _preferences;
  List<Website> _sites;
  String? _selectedId;
  Future<void> _pending = Future.value();
  String? saveError;

  List<Website> get sites => List.unmodifiable(_sites);
  String? get selectedId => _selectedId;
  Website? get selected => _sites.where((s) => s.id == _selectedId).firstOrNull;

  static Future<WebsiteStore> load({
    SharedPreferences? preferences,
    LegacyReader? legacyReader,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    List<Website> sites = [];
    String? selected;
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        sites = _decodeSites(data['websites']);
        selected = data['selectedId'] as String?;
      } catch (_) {
        await prefs.setString('$storageKey.backup', raw);
      }
    } else {
      final legacy = await (legacyReader ?? _readLegacy)();
      if (legacy != null) {
        sites = _decodeSites(legacy['websites']);
        selected = legacy['selectedId'] as String?;
      }
    }
    selected = sites.any((s) => s.id == selected)
        ? selected
        : sites.firstOrNull?.id;
    return WebsiteStore._(prefs, sites, selected);
  }

  static List<Website> _decodeSites(dynamic value) {
    final entries = value is String ? jsonDecode(value) : value;
    final sites = (entries as List)
        .map(
          (entry) => Website.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    if (sites.map((s) => s.id).toSet().length != sites.length) {
      throw const FormatException('Identificadors duplicats.');
    }
    return sites;
  }

  static Future<Map<String, dynamic>?> _readLegacy() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await const MethodChannel(
        'eduweb/migration',
      ).invokeMapMethod<String, dynamic>('readLegacyWebsites');
    } on MissingPluginException {
      return null;
    }
  }

  void save(Website site) {
    final index = _sites.indexWhere((s) => s.id == site.id);
    _sites = [..._sites];
    if (index < 0) {
      _sites.add(site);
    } else {
      _sites[index] = site;
    }
    _selectedId = site.id;
    _persist();
  }

  void select(String id) {
    if (_selectedId == id || !_sites.any((s) => s.id == id)) return;
    _selectedId = id;
    _persist();
  }

  void remove(String id) {
    _sites = _sites.where((s) => s.id != id).toList();
    if (!_sites.any((s) => s.id == _selectedId)) {
      _selectedId = _sites.firstOrNull?.id;
    }
    _persist();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    _sites = [..._sites];
    final site = _sites.removeAt(oldIndex);
    _sites.insert(newIndex, site);
    _persist();
  }

  String exportBackup() => WebsiteBackup.encode(_sites, _selectedId);

  ImportResult importBackup(WebsiteBackup backup, {required ImportMode mode}) {
    if (mode == ImportMode.replace) {
      _sites = [...backup.websites];
      _selectedId = backup.selectedId;
      _persist();
      return ImportResult(added: _sites.length, skipped: 0);
    }
    final sites = [..._sites];
    final ids = sites.map((site) => site.id).toSet();
    String addressKey(Website site) {
      final url = site.url.normalizePath();
      return url.replace(path: url.path.isEmpty ? '/' : url.path).toString();
    }

    final byAddress = {for (final site in sites) addressKey(site): site.id};
    final importedIds = <String, String>{};
    var added = 0;
    var skipped = 0;
    for (final site in backup.websites) {
      final address = addressKey(site);
      final existingId = byAddress[address];
      if (existingId != null) {
        importedIds[site.id] = existingId;
        skipped++;
        continue;
      }
      var saved = site;
      if (ids.contains(site.id)) {
        final newId = Website.create(
          name: site.name,
          address: site.url.toString(),
        ).id;
        saved = Website.fromJson({...site.toJson(), 'id': newId});
      }
      sites.add(saved);
      ids.add(saved.id);
      byAddress[address] = saved.id;
      importedIds[site.id] = saved.id;
      added++;
    }
    _sites = sites;
    _selectedId ??= importedIds[backup.selectedId] ?? sites.firstOrNull?.id;
    _persist();
    return ImportResult(added: added, skipped: skipped);
  }

  void retrySave() => _persist();
  Future<void> flush() => _pending;

  void _persist() {
    final snapshot = jsonEncode({
      'version': 1,
      'websites': _sites.map((s) => s.toJson()).toList(),
      'selectedId': _selectedId,
    });
    saveError = null;
    _pending = _pending
        .then((_) async {
          if (!await _preferences.setString(storageKey, snapshot)) {
            throw StateError('No s’ha pogut guardar.');
          }
        })
        .catchError((Object _) {
          saveError = 'No s’ha pogut guardar la llista. Torna a intentar-ho.';
          notifyListeners();
        });
    notifyListeners();
  }
}
