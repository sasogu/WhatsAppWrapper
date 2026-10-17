import 'package:flutter/material.dart';
import '../data/website_store.dart';
import '../data/website_backup.dart';
import '../data/website_transfer_files.dart';
import '../model/website.dart';
import 'site_icons.dart';
import 'website_editor.dart';

Future<void> editWebsite(
  BuildContext context,
  WebsiteStore store, [
  Website? site,
]) async {
  final saved = await Navigator.of(
    context,
  ).push<Website>(MaterialPageRoute(builder: (_) => WebsiteEditor(site: site)));
  if (saved != null) store.save(saved);
}

class WebsiteManager extends StatefulWidget {
  const WebsiteManager({
    super.key,
    required this.store,
    this.files = const DeviceWebsiteTransferFiles(),
  });
  final WebsiteStore store;
  final WebsiteTransferFiles files;

  @override
  State<WebsiteManager> createState() => _WebsiteManagerState();
}

class _WebsiteManagerState extends State<WebsiteManager> {
  bool _transferring = false;
  WebsiteStore get store => widget.store;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    setState(() => _transferring = true);
    try {
      if (await widget.files.save(store.exportBackup())) {
        _message('Còpia de webs exportada.');
      }
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('No s’ha pogut exportar la còpia de webs.');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _import() async {
    setState(() => _transferring = true);
    try {
      final content = await widget.files.read();
      if (content == null || !mounted) return;
      final backup = WebsiteBackup.decode(content);
      final mode = await showDialog<ImportMode>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Importa les webs'),
          content: Text(
            'El fitxer conté ${backup.websites.length} webs. La llista actual en té ${store.sites.length}.\n\nCombina les llistes sense duplicar adreces, o substituïx la llista actual per la del fitxer. No s’importen sessions ni contrasenyes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·la'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImportMode.replace),
              child: const Text('Substituïx'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ImportMode.merge),
              child: const Text('Combina'),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;
      final result = store.importBackup(backup, mode: mode);
      await store.flush();
      _message(
        store.saveError ??
            (mode == ImportMode.replace
                ? 'Llista substituïda: ${result.added} webs.'
                : 'Webs afegides: ${result.added}. Duplicades omeses: ${result.skipped}.'),
      );
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('No s’ha pogut importar la còpia de webs.');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Les meues webs'),
      actions: [
        if (_transferring)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        PopupMenuButton<String>(
          tooltip: 'Importa o exporta',
          enabled: !_transferring,
          onSelected: (value) {
            if (value == 'export') {
              _export();
            } else {
              _import();
            }
          },
          icon: const Icon(Icons.import_export),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'export', child: Text('Exporta les webs')),
            PopupMenuItem(value: 'import', child: Text('Importa les webs')),
          ],
        ),
        IconButton(
          onPressed: () => editWebsite(context, store),
          icon: const Icon(Icons.add),
          tooltip: 'Afig una web',
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: store.sites.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: () => editWebsite(context, store),
                    icon: const Icon(Icons.add),
                    label: const Text('Afig una web'),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  buildDefaultDragHandles: false,
                  itemCount: store.sites.length,
                  onReorder: store.reorder,
                  itemBuilder: (context, index) {
                    final site = store.sites[index];
                    return ListTile(
                      key: ValueKey(site.id),
                      leading: Icon(siteIcon(site.icon)),
                      title: Text(site.name),
                      subtitle: Text(site.url.host),
                      onTap: () => editWebsite(context, store, site),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Elimina ${site.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => store.remove(site.id),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    ),
  );
}
