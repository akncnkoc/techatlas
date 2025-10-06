import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

Future<String> resolvePdfPath(String assetPath) async {
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return assetPath;
  }
  final data = await rootBundle.load(assetPath);
  final file = File(
    '${Directory.systemTemp.path}/${assetPath.split('/').last}',
  );
  await file.writeAsBytes(data.buffer.asUint8List());
  return file.path;
}
