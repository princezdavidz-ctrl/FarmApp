<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class LoginOtpNotification extends Notification
{
    use Queueable;

    public function __construct(private readonly string $code)
    {
    }

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Your Farm App sign-in code')
            ->greeting('Sign-in verification')
            ->line('Use this one-time code to finish signing in:')
            ->line($this->code)
            ->line('This code expires in 10 minutes. If you did not request it, you can ignore this email.');
    }
}
