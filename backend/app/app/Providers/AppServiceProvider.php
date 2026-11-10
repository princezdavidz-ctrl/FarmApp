<?php

namespace App\Providers;

use App\Models\FarmNotification;
use App\Observers\FarmNotificationObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        FarmNotification::observe(FarmNotificationObserver::class);
    }
}
