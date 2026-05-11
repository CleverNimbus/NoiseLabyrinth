// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

class SaveRenderResult {
  const SaveRenderResult({required this.saved, this.path, this.downloaded = false});

  final bool saved;
  final String? path;
  final bool downloaded;
}

Future<SaveRenderResult> saveRenderBytes({required String suggestedFileName, required Uint8List bytes}) async {
  final blob = html.Blob(<dynamic>[bytes], 'audio/mpeg');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = suggestedFileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return const SaveRenderResult(saved: true, downloaded: true);
}
