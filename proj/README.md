# FarmApp — Primary Flutter Application\n\nThis directory (`proj/`) is the canonical Flutter application for FarmApp. New farm-management features, fixes, and shared design changes should be made here first. The separate `ios-app/` directory is a historical parallel copy; it must not be treated as a second source of truth. Review and selectively port any platform-specific or newer changes from `ios-app/` before changing or retiring it.\n\nBuild the app with the backend URL supplied at build time:\n\n```sh\nflutter pub get\nflutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1\n```\n\nFor a deployed build, replace that local emulator URL with the real HTTPS API origin, ending in `/api/v1`. Configure Firebase app registrations and platform configuration separately; do not copy credentials into source control.\n\n# Farm App

## Phase 2 Foundation

Farm App uses a layered Flutter structure. Phase 2 provides the application
shell, navigation, design system, environment configuration, reusable UI, and
Riverpod state-management foundation. Authentication and feature business
logic are intentionally deferred.

### Startup

`lib/main.dart` is the only application entry point. It calls
`WidgetsFlutterBinding.ensureInitialized()` before `runApp`, which gives
plugins and platform services a safe initialization boundary. `MyApp` in
`lib/app/app.dart` owns the Riverpod `ProviderScope` and the Material 3 app
shell.

### Application Shell

- `lib/app/app.dart`: `MyApp` creates `ProviderScope`; `_AppMaterial` creates
	`MaterialApp.router`, applies the theme, disables the debug banner, and
	exposes the English localization placeholder.
- `lib/app/routes/app_routes.dart`: central route-name constants.
- `lib/app/routes/app_router.dart`: the `GoRouter` instance, nested
	`ShellRoute`, section routes, and bottom-navigation shell.
- `lib/app/routes/route_guard.dart`: authentication-free redirect boundary;
	it currently returns `null` and is ready for a future auth provider.

### Design System

- `app_colors.dart`: shared application colors for surfaces, text, and status
	states.
- `app_typography.dart`: shared Material text styles and weights.
- `app_dimensions.dart`: shared spacing, radius, page padding, and control
	dimensions.
- `app_theme.dart`: Material 3 `ThemeData`, AppBar, Card, input, and button
	defaults.

### Environment

`lib/app/config/environment.dart` defines Development, Staging, and
Production. `api_config.dart` maps each environment to its API base URL.
`AppConfig` exposes the selected environment, URL, and convenience flags.
The default is Development and no network call is made by Phase 2.

### Shared UI and State

`lib/shared/widgets/` contains reusable buttons, cards, fields, loading,
empty, error, and confirmation components. `shared/components/` contains the
custom AppBar and bottom-navigation component. `shared/layouts/` is reserved
for responsive layout implementations.

`theme_provider.dart` provides a Riverpod `ThemeModeNotifier` with light/dark
mode operations. `connectivity_provider.dart` defines an offline-safe
connectivity state with an initial `unknown` value; a platform connectivity
adapter can be added later without changing UI consumers.

### Clean Architecture Boundaries

Feature modules are split into `data`, `domain`, and `presentation`. Data owns
datasources, DTOs, and repository implementations. Domain owns entities,
repository contracts, and use cases. Presentation owns pages, providers, and
widgets. Core contains cross-feature services, storage, sync, errors, and
utilities. Security is isolated under `lib/security/` for later phases.

### Validation

```text
flutter analyze
flutter test
```

Both commands pass for the current Phase 2 foundation.

## Phase 3 Authentication Foundation

Phase 3 adds authentication and session-management boundaries without
implementing herd, breeding, feed, finance, or other business workflows.

### Auth Architecture

`lib/features/auth` follows Clean Architecture:

- `data`: Laravel-ready request/response DTOs, remote/local datasource
	contracts, and `AuthRepositoryImpl`.
- `domain`: immutable `User`, `Farm`, and `Session` entities; the repository
	contract; and login, logout, refresh, farm-selection, and forgot-password
	use cases.
- `presentation`: splash, login, password-reset, farm-selection, and expired
	session screens plus form, password, farm, and biometric widgets.

`UnconfiguredAuthRemoteDataSource` deliberately throws for network login and
refresh until the Laravel endpoints are connected. This keeps offline builds
honest: no credential is accepted locally as a successful remote login.
`AuthLocalDataSourceImpl` persists access token, refresh token, user profile,
and selected farm through `flutter_secure_storage`.

### Security

`AuthService` centralizes secure-storage keys and remember-me/session timestamp
operations. `SessionManager` applies the session lifetime, while
`RefreshTokenLifecycle` identifies expired sessions. `BiometricAuth` wraps
`local_auth`; `PinAuth` provides a device PIN boundary; `InactivityTimer`
performs automatic expiry callbacks; and the audit classes record security
activity. `TokenValidator` provides a minimal non-empty token check.

Roles and permissions are defined in `lib/security/authorization`. The seven
SRS roles map to feature permissions through `RolePermissions`, and
`PermissionGuard` provides route or feature-level checks. `RouteGuard` marks
public auth paths and is the integration point for the authenticated Riverpod
session state when the API session bootstrap is connected.

### Routing

`GoRouter` exposes public splash/login/reset/expired routes and a nested shell
for the application sections. Protected-route classification is centralized
in `RouteGuard`; dashboard and business screens remain available as the
offline Phase 2 shell until authentication bootstrap is connected to a real
session provider.

### Important Security Boundary

`AesEncryption` and `TokenCipher` are compatibility boundaries only and do not
replace cryptographic key management. Production token confidentiality is
provided by `flutter_secure_storage`; any server-side encrypted payload needs
to use the Laravel key-management contract before release.

### Local service configuration

API endpoints and Firebase client configuration are intentionally not bundled.
Pass your API URL with `--dart-define=API_BASE_URL=https://your-api.example/api/v1`
and add your own Firebase platform configuration locally before using sign-in
or push notifications. Generate and protect your own release-signing key.

Support channels are optional build-time settings: `SUPPORT_EMAIL`,
`SUPPORT_WHATSAPP`, and `VETERINARY_PHONE`. Provide only contacts for your own
deployment with `--dart-define`; no support phone, email, or chat destination
is bundled in the source.
