<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\PasswordResetController;

Route::get('/', function () {
    return response()->json([
        'status' => 'ok',
        'service' => config('app.name', 'Farm App'),
    ]);
});

Route::get('/reset-password', [PasswordResetController::class, 'show'])
    ->name('password.reset.query');
Route::get('/reset-password/{token}', [PasswordResetController::class, 'show'])
    ->name('password.reset');
Route::post('/reset-password', [PasswordResetController::class, 'reset'])
    ->name('password.update');
