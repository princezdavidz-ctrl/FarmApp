<?php

namespace Tests\Feature;

use App\Models\RefreshToken;
use App\Models\User;
use App\Notifications\PasswordResetNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class PasswordResetFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_request_email_and_complete_password_reset(): void
    {
        config()->set('services.password_reset.frontend_url', 'https://password.example.invalid/');
        Notification::fake();
        $user = User::factory()->create(['password' => Hash::make('old-password')]);
        $accessToken = $user->createToken('mobile')->accessToken;
        $refreshToken = RefreshToken::create([
            'user_id' => $user->id,
            'token_hash' => hash('sha256', 'refresh-token-value'),
            'remember_me' => true,
            'expires_at' => now()->addDays(30),
        ]);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email])
            ->assertOk()
            ->assertJsonPath('message', 'If that email is registered, a reset link has been sent.');

        $plainToken = null;
        Notification::assertSentTo($user, PasswordResetNotification::class, function (PasswordResetNotification $notification) use ($user, &$plainToken): bool {
            $plainToken = $notification->token;
            $mail = $notification->toMail($user);
            $this->assertSame('emails.auth.password-reset', $mail->view);
            $this->assertStringStartsWith(
                'https://password.example.invalid/?',
                $mail->viewData['resetUrl'],
            );
            $this->assertStringNotContainsString(
                'api.example.invalid',
                $mail->viewData['resetUrl'],
            );
            $this->assertStringContainsString($plainToken, $mail->viewData['resetUrl']);
            $this->assertStringContainsString(rawurlencode($user->email), $mail->viewData['resetUrl']);
            $renderedMail = view($mail->view, $mail->viewData)->render();
            $this->assertStringContainsString(
                'href="'.htmlspecialchars($mail->viewData['resetUrl'], ENT_QUOTES, 'UTF-8').'"',
                $renderedMail,
            );

            return true;
        });
        $this->assertNotNull($plainToken);

        $this->get(route('password.reset', ['token' => $plainToken, 'email' => $user->email]))
            ->assertOk()
            ->assertSee('Set a new password')
            ->assertSee($user->email)
            ->assertSee('name="password_confirmation"', false)
            ->assertSee('viewport-fit=cover', false)
            ->assertSee('Save new password');

        $this->post(route('password.update'), [
            'token' => $plainToken,
            'email' => $user->email,
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ])->assertOk()->assertSee('Password updated');

        $this->assertTrue(Hash::check('new-password-123', $user->fresh()->password));
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $accessToken->id]);
        $this->assertNotNull($refreshToken->fresh()->revoked_at);
        $this->assertDatabaseMissing('password_reset_tokens', ['email' => $user->email]);
    }

    public function test_invalid_password_reset_token_does_not_change_password(): void
    {
        $user = User::factory()->create(['password' => Hash::make('old-password')]);

        $this->post(route('password.update'), [
            'token' => 'invalid-token',
            'email' => $user->email,
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ])->assertRedirect();

        $this->assertTrue(Hash::check('old-password', $user->fresh()->password));
    }

    public function test_user_can_reset_password_through_the_api_frontend_endpoint(): void
    {
        Notification::fake();
        $user = User::factory()->create(['password' => Hash::make('old-password')]);
        $accessToken = $user->createToken('mobile')->accessToken;
        $refreshToken = RefreshToken::create([
            'user_id' => $user->id,
            'token_hash' => hash('sha256', 'refresh-token-value'),
            'remember_me' => true,
            'expires_at' => now()->addDays(30),
        ]);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email])
            ->assertOk();
        $plainToken = null;
        Notification::assertSentTo(
            $user,
            PasswordResetNotification::class,
            function (PasswordResetNotification $notification) use (&$plainToken): bool {
                $plainToken = $notification->token;

                return true;
            },
        );

        $this->postJson('/api/v1/auth/reset-password', [
            'token' => $plainToken,
            'email' => $user->email,
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ])->assertOk()
            ->assertJsonPath(
                'message',
                'Your password has been updated. You can now sign in to FarmApp.',
            );

        $this->assertTrue(Hash::check('new-password-123', $user->fresh()->password));
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $accessToken->id]);
        $this->assertNotNull($refreshToken->fresh()->revoked_at);
        $this->assertDatabaseMissing('password_reset_tokens', ['email' => $user->email]);
    }
}
