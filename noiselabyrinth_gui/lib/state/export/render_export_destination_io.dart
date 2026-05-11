import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SaveRenderResult {
  const SaveRenderResult({required this.saved, this.path, this.downloaded = false});

  final bool saved;
  final String? path;
  final bool downloaded;
}

Future<SaveRenderResult> saveRenderBytes({required String suggestedFileName, required Uint8List bytes}) async {
  final selectedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Export Render',
    fileName: suggestedFileName,
    type: FileType.custom,
    allowedExtensions: const <String>['mp3'],
  );

  if (selectedPath != null && selectedPath.trim().isNotEmpty) {
    final file = File(selectedPath);
    await file.writeAsBytes(bytes, flush: true);
    return SaveRenderResult(saved: true, path: file.path);
  }

  if (Platform.isAndroid) {
    final fallbackDir =
        await getDownloadsDirectory() ??
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final fallbackPath = '${fallbackDir.path}${Platform.pathSeparator}$suggestedFileName';
    final file = File(fallbackPath);
    await file.writeAsBytes(bytes, flush: true);
    return SaveRenderResult(saved: true, path: file.path);
  }

  return const SaveRenderResult(saved: false);
}
