import 'dart:io';

String localApiOrigin() {
  if (Platform.isAndroid) return 'http://10.0.2.2';
  return 'http://localhost';
}
