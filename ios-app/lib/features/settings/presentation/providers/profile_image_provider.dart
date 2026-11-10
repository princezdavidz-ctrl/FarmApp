import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

final profileImageProvider =
    AsyncNotifierProvider<ProfileImageNotifier, String?>(
      ProfileImageNotifier.new,
    );

class ProfileImageNotifier extends AsyncNotifier<String?> {
  static const _storageKey = 'profile_image_path';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> build() => _storage.read(key: _storageKey);

  Future<bool> chooseFromGallery() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (image == null) return false;

    final directory = await getApplicationDocumentsDirectory();
    final savedImage = File('${directory.path}/profile-image.jpg');
    await File(image.path).copy(savedImage.path);
    await _storage.write(key: _storageKey, value: savedImage.path);
    state = AsyncData(savedImage.path);
    return true;
  }
}
