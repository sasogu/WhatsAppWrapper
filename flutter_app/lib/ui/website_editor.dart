import 'package:flutter/material.dart';
import '../model/website.dart';
import 'site_icons.dart';

class WebsiteEditor extends StatefulWidget {
  const WebsiteEditor({super.key, this.site});
  final Website? site;
  @override
  State<WebsiteEditor> createState() => _WebsiteEditorState();
}

class _WebsiteEditorState extends State<WebsiteEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.site?.name ?? '');
  late final _address = TextEditingController(
    text: widget.site?.url.toString() ?? '',
  );
  late String _icon = siteIcons.containsKey(widget.site?.icon)
      ? widget.site!.icon
      : 'globe';
  late bool _desktop = widget.site?.desktop ?? false;
  late bool _external = widget.site?.externalLinks ?? false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final site = Website.create(
      id: widget.site?.id,
      name: _name.text,
      address: _address.text,
      icon: _icon,
      desktop: _desktop,
      externalLinks: _external,
    );
    Navigator.pop(context, site);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.site == null ? 'Afig una web' : 'Edita la web'),
      actions: [TextButton(onPressed: _save, child: const Text('Guarda'))],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                key: const Key('site-name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (value) => value!.trim().isEmpty
                    ? 'Escriu un nom per a la web.'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('site-address'),
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adreça web',
                  hintText: 'https://exemple.org',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _save(),
                validator: (value) {
                  try {
                    Website.parseAddress(value!);
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 24),
              Text('Icona', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: siteIcons.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value.$2),
                        avatar: Icon(entry.value.$1, size: 18),
                        selected: _icon == entry.key,
                        onSelected: (_) => setState(() => _icon = entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vista d’escriptori'),
                subtitle: const Text(
                  'Per a webs que necessiten la versió d’ordinador.',
                ),
                value: _desktop,
                onChanged: (value) => setState(() => _desktop = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enllaços externs en el navegador'),
                subtitle: const Text(
                  'Obri els enllaços a altres dominis fora d’EduWeb.',
                ),
                value: _external,
                onChanged: (value) => setState(() => _external = value),
              ),
              const SizedBox(height: 16),
              const Text(
                'Si omets el protocol, s’utilitza HTTPS. La llista es guarda en este dispositiu.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
