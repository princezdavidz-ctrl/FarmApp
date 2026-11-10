# Supplier

Separate Flutter app for businesses supplying animal feed, medicines,
equipment, and other livestock products through Farm App.

## Features

- Neutral splash and welcome screens
- Supplier registration with business registration number, business name,
  county, and product categories
- Backend verification status and approval workflow
- OTP-backed login using the existing Farm App auth service
- Backend-managed KES subscription plans and M-Pesa STK Push
- Supplier dashboard with product listing creation, editing, stock tracking,
  and listing activation
- Supplies transport requests with online-driver matching, request status
  refresh, cancellation of open requests, and accepted-driver contact details
- Supplier-amber accent theme, distinct from the farm, driver, buyer, and
  veterinary apps
- Business profile
- Access and refresh tokens stored using platform secure storage

## Run

From this directory, install Flutter dependencies and start the app:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.example.invalid/api/v1
```

For a local Android emulator, use the backend host reachable from the emulator:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

The API base defaults to the non-routable placeholder
`https://api.example.invalid/api/v1`. Override it with
`--dart-define=API_BASE_URL=...` for staging or development.

## Backend prerequisites

Apply the Laravel migrations. A CRM administrator must approve each application
and create at least one active plan at
`/api/v1/crm/animal-supplier-subscription-plans` before the app can accept a
subscription. M-Pesa requires the backend Daraja configuration and publicly
reachable HTTPS callback documented in `../backend/README.md`. Products can be
managed after both approval and successful subscription payment. The Flutter
client never marks an account or payment approved by itself.

Suppliers with an active subscription can request supplies transport from the
dashboard. Requests specify the vehicle type, pickup and destination
coordinates, and addresses. The backend offers each request to a nearby online
driver with a matching vehicle/service and recent location. Open requests can
be cancelled, and accepted requests show the assigned driver's contact details.
