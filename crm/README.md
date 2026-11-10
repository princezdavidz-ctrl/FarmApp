# FarmApp CRM

## Farm finance and operations

The Finance workspace's **Farm income & expenses** page uses the farm-scoped finance API. Its entries are separate from subscription collections and CRM revenue reports. Farm operations supports adding and editing records only for modules where the signed-in farm member has the corresponding management permission; reports remain read-only.

Profile pictures are uploaded to the API and shared across sessions. The API deployment must run the avatar migration and expose Laravel's public storage disk (run `php artisan storage:link` if the `public/storage` link is not present). Support inbox messages retain server-side read timestamps and unread counts.

Farm-wide CRM broadcasts create an unread in-app notification for each active farm app member. The Android/iOS app displays unread notifications in its top banner and refreshes notification data every 30 seconds while open. New registrations receive a personal welcome notification in their farm.
