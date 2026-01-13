// Stub implementation for non-web platforms
import 'dart:typed_data';

Future<void> saveFileWeb(String fileName, Uint8List bytes) async {
  throw UnsupportedError('Web-only function called on non-web platform');
}
