String? resolveApiAssetUrl(String? value, {required String apiBaseUrl}) {
  final path = value?.trim();
  if (path == null || path.isEmpty) return null;

  final imageUri = Uri.tryParse(path);
  final apiUri = Uri.tryParse(apiBaseUrl);
  if (imageUri == null || apiUri == null || !apiUri.hasAuthority) return path;

  final imageHost = imageUri.host.toLowerCase();
  final origin = apiUri.replace(path: '/', query: null, fragment: null);
  if (imageUri.hasScheme && imageUri.hasAuthority) {
    if (imageHost != 'localhost' &&
        imageHost != '127.0.0.1' &&
        imageHost != '0.0.0.0') {
      return path;
    }
    return origin
        .replace(
          path: imageUri.path,
          query: imageUri.hasQuery ? imageUri.query : null,
          fragment: imageUri.hasFragment ? imageUri.fragment : null,
        )
        .toString();
  }
  return origin.resolveUri(imageUri).toString();
}
