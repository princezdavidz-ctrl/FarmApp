<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\FarmNotification;
use App\Models\FeedReminder;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class FeedReminderApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_feed_manager_can_sync_and_disable_push_reminders(): void
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Reminder farm']);
        $farm->users()->attach($user->id);

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/farms/{$farm->id}/feed/reminders", [
                'enabled' => true,
                'timezone' => 'Africa/Nairobi',
                'entries' => [
                    [
                        'id' => 'morning',
                        'name' => 'Morning feeding',
                        'minutes_after_midnight' => 390,
                        'reminders_enabled' => true,
                    ],
                ],
            ])
            ->assertOk();

        $this->assertDatabaseHas('feed_reminders', [
            'farm_id' => $farm->id,
            'user_id' => $user->id,
            'schedule_id' => 'morning',
            'minutes_after_midnight' => 390,
            'timezone' => 'Africa/Nairobi',
            'enabled' => true,
        ]);

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/farms/{$farm->id}/feed/reminders", [
                'enabled' => false,
                'timezone' => 'Africa/Nairobi',
                'entries' => [],
            ])
            ->assertOk();

        $this->assertDatabaseMissing('feed_reminders', [
            'farm_id' => $farm->id,
            'user_id' => $user->id,
        ]);
    }

    public function test_scheduler_creates_one_pushable_notification_per_local_day(): void
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Reminder farm']);
        $farm->users()->attach($user->id);
        FeedReminder::create([
            'farm_id' => $farm->id,
            'user_id' => $user->id,
            'schedule_id' => 'morning',
            'name' => 'Morning feeding',
            'minutes_after_midnight' => 390,
            'timezone' => 'Africa/Nairobi',
            'enabled' => true,
        ]);
        Carbon::setTestNow(Carbon::parse('2026-10-14 06:30:00', 'Africa/Nairobi'));

        try {
            Artisan::call('feed:send-reminders');
            Artisan::call('feed:send-reminders');
        } finally {
            Carbon::setTestNow();
        }

        $this->assertSame(1, FarmNotification::query()
            ->where('farm_id', $farm->id)
            ->where('recipient_id', $user->id)
            ->where('type', 'feed_reminder')
            ->count());
    }

    public function test_feed_reminder_sync_rejects_duplicate_schedule_ids(): void
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Reminder farm']);
        $farm->users()->attach($user->id);

        $this->actingAs($user, 'sanctum')
            ->putJson("/api/v1/farms/{$farm->id}/feed/reminders", [
                'enabled' => true,
                'timezone' => 'Africa/Nairobi',
                'entries' => [
                    [
                        'id' => 'morning',
                        'name' => 'Morning feeding',
                        'minutes_after_midnight' => 390,
                        'reminders_enabled' => true,
                    ],
                    [
                        'id' => 'morning',
                        'name' => 'Second morning feeding',
                        'minutes_after_midnight' => 420,
                        'reminders_enabled' => false,
                    ],
                ],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('entries.1.id');
    }
}
