# Veterinarian

Separate Flutter app for veterinary professionals using Farm App.

## Features

- Neutral splash and welcome screens
- Veterinary registration with license, clinic, county, and experience details
- Backend verification status and approval workflow
- OTP-backed login using the existing Farm App auth service
- Backend-managed KES subscription plans and M-Pesa STK Push
- Home and professional profile screens
- Access and refresh tokens stored using platform secure storage
- Veterinary-teal accent theme, distinct from the farm, driver, supplier, and
  buyer apps

## Run

From this directory, install Flutter dependencies and start the app:

```sh
flutter pub get
flutter run
```

For a local Android emulator, use the backend host reachable from the emulator:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Debug builds use the local backend automatically (`localhost` for desktop/iOS and `10.0.2.2` for Android emulators). Release builds require a real API URL supplied with `--dart-define=API_BASE_URL=https://<your-api-host>/api/v1`.

## Backend prerequisites

Apply the Laravel migrations. A CRM administrator must approve each application
and create at least one active plan at `/api/v1/crm/veterinary-subscription-plans`
before the app can accept a subscription. M-Pesa requires the backend Daraja
configuration and publicly reachable HTTPS callback documented in
`../backend/README.md`. The Flutter client never marks an account or payment
approved by itself.
