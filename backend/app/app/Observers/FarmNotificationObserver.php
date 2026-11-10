<?php

namespace App\Observers;

use App\Models\FarmNotification;
use App\Services\Notifications\FirebasePushService;
use Illuminate\Contracts\Events\ShouldHandleEventsAfterCommit;
use Illuminate\Support\Facades\Log;
use Throwable;

class FarmNotificationObserver implements ShouldHandleEventsAfterCommit
{
    public function __construct(private readonly FirebasePushService $push) {}

    public function created(FarmNotification $notification): void
    {
        try {
            $this->push->send($notification);
        } catch (Throwable $error) {
            Log::error('Could not send farm notification push.', [
                'notification_id' => $notification->id,
                'exception' => $error,
            ]);
        }
    }
}
