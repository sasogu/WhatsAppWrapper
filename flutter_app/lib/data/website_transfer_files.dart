import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'website_backup.dart';

abstract interface class WebsiteTransferFiles {
  Future<String?> read();
  Future<bool> save(String content);
}

class DeviceWebsiteTransferFiles implements WebsiteTransferFiles {
  const DeviceWebsiteTransferFiles();

  @override
  Future<String?> read() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importa les webs',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withReadStream: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > WebsiteBackup.maxBytes) {
      throw const FormatException('El fitxer supera el límit d’1 MB.');
    }
    final stream =
        file.readStream ??
        (file.path == null
            ? null
            : File(file.path!).openRead(0, WebsiteBackup.maxBytes + 1));
    if (stream == null) {
      throw const FormatException('No s’ha pogut llegir el fitxer.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > WebsiteBackup.maxBytes) {
        throw const FormatException('El fitxer supera el límit d’1 MB.');
      }
      bytes.add(chunk);
    }
    try {
      return utf8.decode(bytes.takeBytes());
    } catch (_) {
      throw const FormatException(
        'El fitxer no és un document de text UTF-8 vàlid.',
      );
    }
  }

  @override
  Future<bool> save(String content) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporta les webs',
      fileName: 'eduweb-webs-$date.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    return path != null;
  }
}
