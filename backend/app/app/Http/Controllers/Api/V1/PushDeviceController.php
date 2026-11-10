<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PushDevice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PushDeviceController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:4096'],
            'platform' => ['required', 'string', 'in:android,ios'],
        ]);
        $tokenHash = hash('sha256', $validated['token']);

        PushDevice::query()->updateOrCreate(
            ['token_hash' => $tokenHash],
            [
                'user_id' => $request->user()->id,
                'token' => $validated['token'],
                'platform' => $validated['platform'],
            ],
        );

        return response()->json(['message' => 'Push device registered.']);
    }

    public function destroy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:4096'],
        ]);

        PushDevice::query()
            ->where('user_id', $request->user()->id)
            ->where('token_hash', hash('sha256', $validated['token']))
            ->delete();

        return response()->json(['message' => 'Push device removed.']);
    }
}
