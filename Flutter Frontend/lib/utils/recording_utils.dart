import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<String> getRecordingFilePath() async {
  final downloadsPath = await _getDownloadsPath();
  final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
  return p.join(downloadsPath, fileName);
}

Future<String> _getDownloadsPath() async {
  if (Platform.isAndroid) {
    final dir = Directory('/storage/emulated/0/Download');
    if (await dir.exists()) return dir.path;
  }
  return (await getDownloadsDirectory())!.path;
}