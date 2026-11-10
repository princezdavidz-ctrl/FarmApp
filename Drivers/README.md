# Driver

Separate Flutter app for drivers transporting livestock, animal feed, medicine,
equipment, or both herds and supplies.

## Features

- Generic welcome screen and driver registration
- Driver licence, vehicle, county, load-capacity, and service verification
- Application review and approval flow
- OTP sign-in, backend-managed subscriptions, and M-Pesa payments
- Home map with driver position and online/offline availability
- Location sharing starts only when the driver goes online, updates on movement
  and every five minutes while the app is in use, and stops when taken offline
  or signed out
- Driver profile with verified vehicle and transport details
- Secure storage for access and refresh tokens
- OpenStreetMap tiles (internet access required)
- Driver-blue accent theme, distinct from the farm, supplier, buyer, and
  veterinary apps

## Run

```sh
flutter pub get
flutter run
```

Debug builds use the local backend automatically (`localhost` for desktop/iOS and `10.0.2.2` for Android emulators). Release builds require a real API URL supplied with `--dart-define=API_BASE_URL=https://<your-api-host>/api/v1`.

For an Android emulator using a local backend:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Drivers must allow location access to go online. The backend stops returning
locations that have not been updated within 15 minutes.

## Backend prerequisites

Apply the Laravel migrations. A CRM administrator must review each application
and create an active subscription plan at
`/api/v1/crm/animal-driver-subscription-plans`. M-Pesa requires the backend
Daraja configuration and public HTTPS callback described in
`../backend/README.md`. Only approved drivers with an active subscription,
online availability, and a recent location appear in nearby-driver search.
