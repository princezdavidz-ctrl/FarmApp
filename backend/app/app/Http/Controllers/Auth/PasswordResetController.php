<?php

namespace App\Http\Controllers\Auth;

use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\View\View;

class PasswordResetController
{
    public function show(Request $request, ?string $token = null): View
    {
        return view('auth.reset-password', [
            'token' => $token ?? (string) $request->query('token', ''),
            'email' => (string) $request->query('email', ''),
            'status' => null,
            'success' => false,
        ]);
    }

    public function reset(Request $request): View|RedirectResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $status = Password::reset($data, function (User $user, string $password): void {
            DB::transaction(function () use ($user, $password): void {
                $user->forceFill([
                    'password' => $password,
                    'remember_token' => Str::random(60),
                ])->save();
                $user->tokens()->delete();
                $user->refreshTokens()->update(['revoked_at' => now()]);
            });
        });

        if ($status !== Password::PASSWORD_RESET) {
            return redirect()->route('password.reset', [
                'token' => $data['token'],
                'email' => $data['email'],
            ])->withErrors(['email' => __($status)]);
        }

        return view('auth.reset-password', [
            'token' => '',
            'email' => $data['email'],
            'status' => 'Your password has been updated. You can now sign in to FarmApp.',
            'success' => true,
        ]);
    }
}
