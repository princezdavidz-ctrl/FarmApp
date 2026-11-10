# pigworld-backend

## Deployment

Copy `backend/.env.docker.example` to `backend/app/.env` and set a real
`APP_KEY`, database passwords, `APP_URL`, and `CORS_ALLOWED_ORIGINS`. Never use
the example passwords in a deployed environment. From the workspace root,
start the stack with:

```bash
cd backend
docker compose --env-file app/.env up --build -d
docker compose --env-file app/.env ps
```

For development and staging only, sign in to the app with the seeded tester
account:

- Email: `test@example.com`
- Password: `password`

The tester account is not created in production. The Compose startup command
also skips the database seeder when `APP_ENV=production`; production data must
be created through an explicitly reviewed migration or administrative process.

### M-Pesa Daraja configuration

For production, set `MPESA_ENV=production` and obtain the consumer key, consumer
secret, business shortcode, passkey, and transaction type from the same
production Daraja app. Use `CustomerPayBillOnline` for a PayBill shortcode or
`CustomerBuyGoodsOnline` for a Till shortcode. The shortcode is sent as both
`BusinessShortCode` and `PartyB`; the STK password is Base64 of the exact
concatenation `BusinessShortCode + passkey + Timestamp`. Never log or share the
consumer credentials or passkey. Set `MPESA_CALLBACK_SECRET` to a unique random
value of at least 32 characters (for example, generate one with
`openssl rand -hex 32`). The backend attaches it to each Daraja callback URL and
rejects callbacks without a matching token. The bundled Nginx config disables
access logging for that callback path; configure any upstream proxy or load
balancer to mask `callback_token` as well. After updating the server `.env`,
rebuild the Laravel config cache.

To seed the account manually after the stack is already running:

```bash
docker compose --env-file app/.env exec backend php artisan db:seed --force
```

Nginx serves the CRM at `/`, forwards `/api/*` and `/up` to Laravel, and keeps
PHP-FPM and MySQL on the private Compose network. TLS must be terminated by an
external load balancer or added to Nginx before exposing the deployment to the
public internet. Set `CORS_ALLOWED_ORIGINS` to exact trusted origins; do not
use a wildcard for the browser CRM.

## Security coverage

- Logout revokes the user's active refresh tokens as well as the access token.
- Authenticated subscription-plan mutations require a farm owner or CRM
	`admin`/`finance` role at both the request and controller layers.
- The CRM currently stores bearer tokens in browser `localStorage`. A future
	hardening pass should migrate browser authentication to secure, HttpOnly
	cookies or use a backend-for-frontend session.
- Production deployment still requires HTTPS enforcement, secret management,
	and a managed durable database/storage service.

### Veterinary app API

The separate `Vetinaries/` Flutter app uses the `/api/v1` API. Apply with
`POST /veterinary-applications`, check the returned reference with
`GET /veterinary-applications/{reference}`, and sign in after approval using
the existing OTP login flow. The application status endpoint returns only the
application state and review note; the random reference is stored in the app's
secure storage.

CRM administrators (`crm_role=admin` or the central CRM administrator) review
applications through `GET /crm/veterinary-applications` and
`PATCH /crm/veterinary-applications/{id}` with `status` set to `approved` or
`rejected`. Configure backend-owned M-Pesa subscription plans through
`GET/POST /crm/veterinary-subscription-plans` and
`PATCH /crm/veterinary-subscription-plans/{id}`. Plan creation requires
`code`, `name`, `amount`, `currency` (`KES`), and `duration_days`; new plans
can be disabled by setting `active` to `false`.

Approved veterinarians load plans from `GET /veterinary-subscription-plans`,
start payment with `POST /veterinarians/subscription/payment`, and check
`GET /veterinarians/payments/{id}`. M-Pesa activation and expiry are updated
only by the existing server-to-server payment callback after a successful
Safaricom confirmation. Configure the same production Daraja credentials and
public HTTPS callback URL and `MPESA_CALLBACK_SECRET` described above before
accepting live payments.

### Animal product supplier app API

The separate Flutter app in `Suppliers/` registers businesses through
`POST /animal-supplier-applications`; application status uses the generated
reference at `GET /animal-supplier-applications/{reference}`. A CRM
administrator reviews the queue with `GET /crm/animal-supplier-applications`
and approves or rejects an application with
`PATCH /crm/animal-supplier-applications/{id}`.

Configure active KES subscription plans through
`GET/POST /crm/animal-supplier-subscription-plans` and
`PATCH /crm/animal-supplier-subscription-plans/{id}`. Approved sellers load
plans from `GET /animal-supplier-subscription-plans`, initiate payment through
`POST /animal-suppliers/subscription/payment`, and check payment status at
`GET /animal-suppliers/payments/{id}`. Product listings are created, updated,
and listed through `/animal-suppliers/products`; access is limited to approved
suppliers with an unexpired subscription. Payment and subscription activation
are driven only by the authenticated Safaricom callback.
Pig farmers and other buyers can discover published products through the public
`GET /api/v1/animal-products` endpoint, with optional `search`, `category`,
`county`, and `per_page` filters. Only active products from approved suppliers
with a current subscription are returned.

### Supplier and farm transport requests

Suppliers create and list their own supplies-transport requests through
`POST/GET /animal-suppliers/transport-requests`; farm members use
`POST/GET /farms/{farm}/transport-requests`. Both clients provide a specific
vehicle type, pickup and destination coordinates and addresses, and optional
load details. Requests default to a 25 km pickup radius (configurable from
1-100 km). Drivers poll `GET /animal-drivers/requests` while online. A request
is offered only to an approved, subscribed, available driver with a location
updated in the last 15 minutes, a matching service and exact vehicle type, and
a location within the pickup radius. Acceptance is atomic so a request can be
claimed by only one driver.

The requester can cancel an open request with
`POST /transport-requests/{id}/status` and `{"status":"cancelled"}`. The
accepting driver can mark it complete through the same endpoint with
`{"status":"completed"}`. Requests are scoped to their creating farm or
supplier when listed; driver name and phone are returned for accepted jobs.

### Animal transport driver app

The separate Flutter app in `Drivers/` accepts applications through
`POST /animal-driver-applications`; status checks use the generated reference
at `GET /animal-driver-applications/{reference}`. Driver applications include
their licence, vehicle details, county, capacity, and one or both transport
services (`herd`, `supplies`). CRM administrators review applications at
`/crm/animal-driver-applications` and manage KES subscription plans at
`/crm/animal-driver-subscription-plans`.

Approved drivers load plans from `GET /animal-driver-subscription-plans`,
start M-Pesa payment through `POST /animal-drivers/subscription/payment`, and
check status through `GET /animal-drivers/payments/{id}`. Subscription
activation depends on the authenticated Safaricom callback. While the app is
open and the driver is online, it posts coordinates to
`POST /animal-drivers/location`. The public
`GET /api/v1/animal-drivers/nearby?latitude=...&longitude=...` endpoint returns
available, approved, subscribed drivers whose location was updated within the
last 15 minutes. It accepts optional `radius_km` (1-100) and `service_type`
(`herd` or `supplies`) filters. Location sharing requires an active
subscription.

### Farm jobs and veterinary requests

Farm owners manage listings with `GET/POST /farms/{farm}/job-postings` and
`PATCH /farms/{farm}/job-postings/{posting}`. Workers browse with
`GET /farm-jobs` and apply through `POST /farm-jobs/{posting}/applications`.
The farm owner reviews an application with
`PATCH /farms/{farm}/job-postings/{posting}/applications/{application}`; an
accepted eligible worker or manager is added to the farm.

Farm members can request veterinary assistance using
`POST/GET /farms/{farm}/veterinary-requests`. Eligible approved veterinarians
with active subscriptions receive open requests in their county through the
veterinary app; acceptance and completion use
`POST /veterinary-requests/{id}/status`. Farm creation accepts
`farming_type` (`crops`, `livestock`, or `mixed`) and a `production_types`
array. An account may create one farm but may join additional farms as staff.

### Private configuration

The environment examples are placeholders only. Copy `app/.env.example` to
`app/.env` for local setup and configure fresh database, mail, Firebase, and
payment credentials in the target environment. Do not commit `.env` files,
service-account files, mobile Firebase configuration, or signing material.
Client API defaults use reserved example domains; provide the target API URL
when building each app.