# FarmApp — Primary Flutter Application

This directory (`proj/`) is the canonical Flutter application for FarmApp.
New farm-management features, fixes, and shared design changes belong here.
The `ios-app/` directory is a retained historical copy, not a second source
of truth. Review and selectively port any useful platform-specific changes
before retiring that copy.

## Application structure

- `lib/main.dart`: Flutter entry point.
- `lib/app/`: app shell, routing, localization, theme, and environment config.
- `lib/features/`: feature modules organised around presentation, domain, and data.
- `lib/core/`: networking, storage, errors, utilities, and shared services.
- `lib/security/`: authentication, session, and authorization boundaries.
- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`: platform runners.

The Laravel API lives in `../backend/app/`; the browser CRM lives in
`../crm/`. The standalone buyer, driver, supplier, and veterinary apps are
maintained in their respective top-level directories.

## Local development

Use Flutter stable with the Dart SDK version required by `pubspec.yaml`.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

The default development API host is `10.0.2.2` for Android emulators and
`localhost` for iOS simulators, desktop, and web. Override it with
`--dart-define=API_BASE_URL=...` when using a LAN address, staging server, or
production server.

Every release build must supply a real HTTPS API endpoint:

```sh
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://<your-api-host>/api/v1
```

Do not ship a release build with a local emulator URL. Firebase configuration,
Google Maps keys, signing keys, and backend credentials must be supplied
through the appropriate platform/environment configuration and must not be
committed to the repository.

## Validation

```sh
flutter analyze
flutter test
```

The repository CI workflow also runs Flutter analysis/tests for the primary
app and the standalone client apps, Laravel backend tests, and a production
CRM build.

## Platform identity migration

The visible product name is FarmApp. Existing mobile application identifiers
and the Firebase project reference are intentionally retained during this
branding pass because changing them without registering matching Firebase
applications and planning an app-store migration can break push notifications,
authentication, upgrades, and existing installations. Complete that migration
as a separate deployment task once the new Firebase registrations and release
identities are ready.
