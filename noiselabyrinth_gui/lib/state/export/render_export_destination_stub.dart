import 'dart:typed_data';

class SaveRenderResult {
  const SaveRenderResult({required this.saved, this.path, this.downloaded = false});

  final bool saved;
  final String? path;
  final bool downloaded;
}

Future<SaveRenderResult> saveRenderBytes({required String suggestedFileName, required Uint8List bytes}) async {
  return const SaveRenderResult(saved: false);
}
