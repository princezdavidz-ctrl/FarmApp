<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RefreshTokenRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\ResendLoginOtpRequest;
use App\Http\Requests\Auth\VerifyLoginOtpRequest;
use App\Http\Resources\FarmResource;
use App\Http\Resources\UserResource;
use App\Models\Farm;
use App\Models\FarmNotification;
use App\Models\LoginOtp;
use App\Models\User;
use App\Notifications\LoginOtpNotification;
use App\Services\Auth\FirebaseIdTokenVerifier;
use App\Services\Auth\TokenIssuer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;
use Throwable;

class AuthController extends Controller
{
    public function __construct(
        private readonly TokenIssuer $tokens,
        private readonly FirebaseIdTokenVerifier $firebaseTokens,
    ) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $role = $request->string('role')->toString();
        $data = $request->validated();

        [$user] = DB::transaction(function () use ($data, $role): array {
            $matches = User::query()
                ->where('email', $data['email'])
                ->orWhere('phone', $data['phone'])
                ->lockForUpdate()
                ->get();

            if ($matches->count() > 1 || ($matches->isNotEmpty() && $role !== 'farmOwner')) {
                throw ValidationException::withMessages([
                    'email' => ['This email or phone number is already linked to an account.'],
                ]);
            }

            $user = $matches->first();
            $isNewUser = $user === null;
            if ($user !== null) {
                if (! Hash::check($data['password'], $user->password)) {
                    throw ValidationException::withMessages([
                        'password' => ['Enter the existing account password to add another farm.'],
                    ]);
                }
                if ($role === 'farmOwner' && (
                    $user->farms()->exists()
                    || Farm::query()->where('created_by', $user->id)->exists()
                )) {
                    throw ValidationException::withMessages([
                        'farm_name' => ['Each account can register only one farm. Staff can still join other farms.'],
                    ]);
                }
            } else {
                $user = User::create([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'phone' => $data['phone'],
                    'password' => Hash::make($data['password']),
                    'role' => $role,
                ]);
            }

            if ($role === 'buyer') {
                $user->buyer()->firstOrCreate([]);
            }

            $farm = $role === 'farmOwner'
                ? Farm::create([
                    'name' => $data['farm_name'],
                    'created_by' => $user->id,
                    'farming_type' => $data['farming_type'] ?? 'mixed',
                    'production_types' => $data['production_types'] ?? [],
                    'mother_pig_count' => $data['mother_pig_count'] ?? 0,
                    'piglet_groups' => $data['piglet_groups'] ?? [],
                    'pregnant_pig_count' => $data['pregnant_pig_count'] ?? 0,
                ])
                : (isset($data['invite_code'])
                    ? Farm::where('invite_code', $data['invite_code'])->firstOrFail()
                    : null);

            if ($farm === null && $role !== 'farmOwner') {
                $farm = $user->farms()->oldest('farms.id')->first();
            }

            if ($farm !== null && ! $user->farms()->whereKey($farm->id)->exists()) {
                $user->farms()->attach($farm->id);
            }

            if ($isNewUser && $farm !== null) {
                FarmNotification::create([
                    'farm_id' => $farm->id,
                    'recipient_id' => $user->id,
                    'type' => 'welcome',
                    'title' => 'Welcome '.$user->name.' to Farm App',
                    'body' => 'We will be with you all the way.',
                    'severity' => 'success',
                    'related_type' => 'user',
                    'related_id' => $user->id,
                    'action_route' => '/home',
                ]);
            }

            return [$user];
        });

        return $this->authResponse($user->fresh());
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $identifier = $request->string('identifier')->toString();
        $user = User::where('email', $identifier)
            ->orWhere('phone', $identifier)
            ->first();

        if ($user === null || $user->crm_closed_at !== null || ! Hash::check($request->string('password'), $user->password)) {
            // Same message whether the identifier exists or not, so we don't leak account existence.
            throw ValidationException::withMessages(['identifier' => ['These credentials do not match our records.']]);
        }

        $code = (string) random_int(100000, 999999);
        $challengeId = (string) Str::uuid();

        LoginOtp::query()->where('user_id', $user->id)->delete();
        LoginOtp::create([
            'challenge_id' => $challengeId,
            'user_id' => $user->id,
            'code_hash' => Hash::make($code),
            'remember_me' => $request->boolean('remember_me'),
            'attempts' => 0,
            'expires_at' => now()->addMinutes(10),
        ]);

        try {
            Notification::send($user, new LoginOtpNotification($code));
        } catch (Throwable $exception) {
            LoginOtp::where('challenge_id', $challengeId)->delete();
            report($exception);
            throw ValidationException::withMessages([
                'identifier' => ['Unable to send a verification code right now. Please try again.'],
            ]);
        }

        return response()->json([
            'otp_required' => true,
            'challenge_id' => $challengeId,
            'destination' => $this->maskedEmail($user->email),
            'expires_in' => 600,
        ]);
    }

    public function verifyLoginOtp(VerifyLoginOtpRequest $request): JsonResponse
    {
        $data = $request->validated();
        [$user, $rememberMe] = DB::transaction(function () use ($data): array {
            $challenge = LoginOtp::query()
                ->where('challenge_id', $data['challenge_id'])
                ->lockForUpdate()
                ->first();

            if ($challenge === null || $challenge->consumed_at !== null || $challenge->expires_at->isPast() || $challenge->attempts >= 5) {
                return [null, false];
            }

            if (! Hash::check($data['code'], $challenge->code_hash)) {
                $challenge->increment('attempts');
                if ($challenge->fresh()->attempts >= 5) {
                    $challenge->update(['consumed_at' => now()]);
                }

                return [null, false];
            }

            $challenge->update(['consumed_at' => now()]);

            return [$challenge->user, $challenge->remember_me];
        });

        if ($user === null || $user->crm_closed_at !== null) {
            throw ValidationException::withMessages([
                'code' => ['The verification code is invalid or has expired.'],
            ]);
        }

        return $this->authResponse($user, $rememberMe);
    }

    public function resendLoginOtp(ResendLoginOtpRequest $request): JsonResponse
    {
        $data = $request->validated();
        [$challenge, $code] = DB::transaction(function () use ($data): array {
            $challenge = LoginOtp::query()
                ->where('challenge_id', $data['challenge_id'])
                ->lockForUpdate()
                ->first();

            if ($challenge === null || $challenge->consumed_at !== null || $challenge->attempts >= 5) {
                throw ValidationException::withMessages([
                    'challenge_id' => ['The sign-in challenge is no longer valid. Sign in again to request a new code.'],
                ]);
            }

            $rateLimitKey = 'login-otp-resend:'.$challenge->user_id;
            if (RateLimiter::tooManyAttempts($rateLimitKey, 3)) {
                throw ValidationException::withMessages([
                    'challenge_id' => ['Too many code requests. Wait a few minutes and try again.'],
                ]);
            }
            RateLimiter::hit($rateLimitKey, 600);

            $code = (string) random_int(100000, 999999);
            $challenge->update([
                'code_hash' => Hash::make($code),
                'attempts' => 0,
                'expires_at' => now()->addMinutes(10),
            ]);

            return [$challenge->fresh('user'), $code];
        });

        try {
            Notification::send($challenge->user, new LoginOtpNotification($code));
        } catch (Throwable $exception) {
            $challenge->update(['consumed_at' => now()]);
            report($exception);
            throw ValidationException::withMessages([
                'challenge_id' => ['Unable to send a verification code right now. Please try again.'],
            ]);
        }

        return response()->json([
            'otp_required' => true,
            'challenge_id' => $challenge->challenge_id,
            'destination' => $this->maskedEmail($challenge->user->email),
            'expires_in' => 600,
        ]);
    }

    public function loginWithGoogle(Request $request): JsonResponse
    {
        return $this->loginWithFirebase($request);
    }

    public function loginWithFirebase(Request $request): JsonResponse
    {
        $idToken = $request->validate(['id_token' => ['required', 'string']])['id_token'];
        $claims = $this->firebaseTokens->verify($idToken);
        $email = $claims['email'] ?? null;
        $provider = $claims['firebase']['sign_in_provider'] ?? null;

        if (! is_string($email)
            || ! filter_var($email, FILTER_VALIDATE_EMAIL)
            || ($claims['email_verified'] ?? false) !== true
            || ! in_array($provider, ['google.com', 'apple.com'], true)) {
            throw ValidationException::withMessages([
                'id_token' => ['The federated account email is not verified or the sign-in provider is not supported.'],
            ]);
        }

        $user = User::where('email', $email)->first();
        if ($user === null || $user->crm_closed_at !== null) {
            throw ValidationException::withMessages(['email' => ['No active Farm App account is associated with this Google email.']]);
        }

        return $this->authResponse($user);
    }

    public function refresh(RefreshTokenRequest $request): JsonResponse
    {
        $stored = $this->tokens->findValid($request->string('refresh_token')->toString());

        if ($stored === null) {
            throw ValidationException::withMessages(['refresh_token' => ['This refresh token is invalid or has expired.']]);
        }

        $this->tokens->revoke($stored);

        return $this->authResponse($stored->user()->firstOrFail(), $stored->remember_me);
    }

    public function logout(Request $request): JsonResponse
    {
        if ($token = $request->bearerToken()) {
            PersonalAccessToken::findToken($token)?->delete();
        }

        $request->user()->refreshTokens()->update(['revoked_at' => now()]);

        return response()->json(null, 204);
    }

    public function logoutAll(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->tokens()->delete();
        $user->refreshTokens()->whereNull('revoked_at')->update(['revoked_at' => now()]);

        return response()->json(['message' => 'All sessions have been revoked.']);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'user' => new UserResource($user),
            'farms' => FarmResource::collection($user->farms),
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:255']]);
        $request->user()->update($data);

        return response()->json(['user' => new UserResource($request->user()->fresh())]);
    }

    public function updateProfileAvatar(Request $request): JsonResponse
    {
        $data = $request->validate([
            'avatar' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
        ]);

        $user = $request->user();
        $path = $data['avatar']->storePublicly('profile-avatars', 'public');
        $oldPath = $user->avatar_path;
        $user->update(['avatar_path' => $path]);
        if ($oldPath !== null) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json(['user' => new UserResource($user->fresh())]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $request->user();
        if (! Hash::check($data['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['The current password is incorrect.'],
            ]);
        }

        $user->update(['password' => Hash::make($data['new_password'])]);

        return response()->json(['message' => 'Password changed successfully.']);
    }

    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        // Always respond the same way to avoid revealing whether an account exists for this email.
        $status = Password::sendResetLink($request->only('email'));

        if (! in_array($status, [Password::RESET_LINK_SENT, Password::INVALID_USER], true)) {
            throw ValidationException::withMessages([
                'email' => [__($status)],
            ]);
        }

        return response()->json(['message' => 'If that email is registered, a reset link has been sent.']);
    }

    public function resetPassword(Request $request): JsonResponse
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
            throw ValidationException::withMessages([
                'email' => [__($status)],
            ]);
        }

        return response()->json([
            'message' => 'Your password has been updated. You can now sign in to Farm App.',
        ]);
    }

    private function maskedEmail(string $email): string
    {
        [$name, $domain] = explode('@', $email, 2);

        return (strlen($name) < 2 ? '*' : substr($name, 0, 1).'***').'@'.$domain;
    }

    private function authResponse(User $user, bool $rememberMe = true): JsonResponse
    {
        $pair = $this->tokens->issue($user, $rememberMe);

        return response()->json([
            'access_token' => $pair['access_token'],
            'refresh_token' => $pair['refresh_token'],
            'user' => new UserResource($user),
            'farms' => FarmResource::collection($user->farms),
        ]);
    }
}
