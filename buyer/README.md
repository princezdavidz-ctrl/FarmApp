# Buyer

Standalone Flutter app for browsing available pigs in a responsive listing grid
and sending a purchase request to the farm owner.

The Buyer app uses a distinct violet accent theme, separate from the farm,
driver, supplier, and veterinary apps.

Run with `flutter pub get` and `flutter run`. To point to a different backend,
use `flutter run --dart-define=API_BASE_URL=https://your-server/api/v1`.

The app uses the public marketplace API. Farm-owner listing management and buyer
request review are available in the sales section of the main FarmApp app.

## Android release signing

Google Play releases must be signed with the app's upload keystore, not the
Android debug key. Copy `android/key.properties.example` to
`android/key.properties`, set its values to your upload keystore credentials,
and place the keystore at the configured `storeFile` path. Keep both files
private. Build the Play upload bundle with:

```sh
flutter build appbundle --release
```

### Local API configuration

Debug builds use the local backend automatically (`localhost` for desktop/iOS and `10.0.2.2` for Android emulators). Release builds require a real API URL supplied with `--dart-define=API_BASE_URL=https://<your-api-host>/api/v1`. Signing keys and Firebase configuration are not included;
provide your own local files and keep them out of source control.
