<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class PasswordResetNotification extends Notification
{
    use Queueable;

    public function __construct(public readonly string $token) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $resetBaseUrl = rtrim((string) config('services.password_reset.frontend_url'), '/');
        $resetPath = str_ends_with($resetBaseUrl, '/reset-password')
            ? $resetBaseUrl
            : $resetBaseUrl.'/';
        $resetUrl = $resetPath.'?'.http_build_query([
                'token' => $this->token,
                'email' => $notifiable->getEmailForPasswordReset(),
            ], '', '&', PHP_QUERY_RFC3986);

        return (new MailMessage)
            ->subject('Reset your Farm App password')
            ->view('emails.auth.password-reset', [
                'name' => $notifiable->name ?: 'there',
                'resetUrl' => $resetUrl,
                'expiresIn' => config('auth.passwords.'.config('auth.defaults.passwords').'.expire', 60),
            ]);
    }
}
