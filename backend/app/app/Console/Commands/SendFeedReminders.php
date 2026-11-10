<?php

namespace App\Console\Commands;

use App\Models\FarmNotification;
use App\Models\FeedReminder;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SendFeedReminders extends Command
{
    protected $signature = 'feed:send-reminders';

    protected $description = 'Send due feeding reminders to registered app devices.';

    public function handle(): int
    {
        FeedReminder::query()->where('enabled', true)->chunkById(100, function ($reminders): void {
            foreach ($reminders as $reminder) {
                $now = now($reminder->timezone);
                if ((int) $now->format('G') * 60 + (int) $now->format('i') !== $reminder->minutes_after_midnight) {
                    continue;
                }

                DB::transaction(function () use ($reminder, $now): void {
                    $locked = FeedReminder::query()->lockForUpdate()->find($reminder->id);
                    if ($locked === null || ! $locked->enabled || $locked->last_sent_on?->toDateString() === $now->toDateString()) {
                        return;
                    }

                    $locked->update(['last_sent_on' => $now->toDateString()]);
                    FarmNotification::query()->create([
                        'farm_id' => $locked->farm_id,
                        'recipient_id' => $locked->user_id,
                        'type' => 'feed_reminder',
                        'title' => 'Feeding reminder',
                        'body' => "{$locked->name} is scheduled now.",
                        'severity' => 'info',
                        'related_type' => 'feed_schedule',
                        'related_id' => null,
                        'action_route' => '/feed',
                    ]);
                });
            }
        });

        return self::SUCCESS;
    }
}
