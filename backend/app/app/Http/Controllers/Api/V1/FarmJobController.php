<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Farm;
use App\Models\FarmJobApplication;
use App\Models\FarmJobPosting;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class FarmJobController extends Controller
{
    public function browse(Request $request): JsonResponse
    {
        abort_unless(
            in_array($request->user()->role, ['farmManager', 'farmWorker'], true),
            403,
            'Farm job listings are available to farm staff.',
        );
        $filters = $request->validate([
            'location' => ['sometimes', 'string', 'max:100'],
        ]);
        $postings = FarmJobPosting::query()
            ->with('farm:id,name,location')
            ->where('status', 'open')
            ->where('role', $request->user()->role)
            ->when(isset($filters['location']), fn ($query) =>
                $query->whereHas('farm', fn ($farm) =>
                    $farm->where('location', 'like', '%'.$filters['location'].'%')
                )
            )
            ->latest()
            ->paginate(30);

        return response()->json([
            'data' => $postings->getCollection()
                ->map(fn (FarmJobPosting $posting): array => $this->postingData($posting)),
            'meta' => [
                'current_page' => $postings->currentPage(),
                'last_page' => $postings->lastPage(),
            ],
        ]);
    }

    public function apply(Request $request, FarmJobPosting $farmJobPosting): JsonResponse
    {
        abort_unless(
            in_array($request->user()->role, ['farmManager', 'farmWorker'], true)
                && $request->user()->role === $farmJobPosting->role,
            403,
            'This listing is not for your account type.',
        );
        abort_unless($farmJobPosting->status === 'open', 409, 'This listing is closed.');
        abort_if(
            $request->user()->farms()->whereKey($farmJobPosting->farm_id)->exists(),
            409,
            'You already belong to this farm.',
        );
        $data = $request->validate([
            'message' => ['nullable', 'string', 'max:2000'],
        ]);
        $application = FarmJobApplication::create([
            'farm_job_posting_id' => $farmJobPosting->id,
            'user_id' => $request->user()->id,
            'message' => $data['message'] ?? null,
            'status' => 'pending',
        ]);

        return response()->json([
            'data' => $this->applicationData($application->load('user:id,name,phone,email')),
        ], 201);
    }

    public function indexForFarm(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeOwner($request, $farm);

        return response()->json([
            'data' => FarmJobPosting::query()
                ->with(['farm:id,name,location', 'applications.user:id,name,phone,email'])
                ->where('farm_id', $farm->id)
                ->latest()
                ->get()
                ->map(fn (FarmJobPosting $posting): array => [
                    ...$this->postingData($posting),
                    'applications' => $posting->applications
                        ->map(fn (FarmJobApplication $application): array => $this->applicationData($application))
                        ->values(),
                ])
                ->values(),
        ]);
    }

    public function store(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeOwner($request, $farm);
        $data = $request->validate([
            'role' => ['required', Rule::in(['farmManager', 'farmWorker'])],
            'title' => ['required', 'string', 'max:150'],
            'description' => ['required', 'string', 'max:4000'],
            'location' => ['nullable', 'string', 'max:255'],
        ]);
        $posting = FarmJobPosting::create([
            ...$data,
            'farm_id' => $farm->id,
            'created_by' => $request->user()->id,
            'status' => 'open',
        ]);

        return response()->json([
            'data' => $this->postingData($posting->load('farm:id,name,location')),
        ], 201);
    }

    public function update(Request $request, Farm $farm, FarmJobPosting $farmJobPosting): JsonResponse
    {
        $this->authorizeOwner($request, $farm);
        abort_unless($farmJobPosting->farm_id === $farm->id, 404);
        $farmJobPosting->update($request->validate([
            'status' => ['required', Rule::in(['open', 'closed'])],
        ]));

        return response()->json([
            'data' => $this->postingData($farmJobPosting->fresh()->load('farm:id,name,location')),
        ]);
    }

    public function reviewApplication(
        Request $request,
        Farm $farm,
        FarmJobPosting $farmJobPosting,
        FarmJobApplication $farmJobApplication,
    ): JsonResponse {
        $this->authorizeOwner($request, $farm);
        abort_unless(
            $farmJobPosting->farm_id === $farm->id
                && $farmJobApplication->farm_job_posting_id === $farmJobPosting->id,
            404,
        );
        $data = $request->validate([
            'status' => ['required', Rule::in(['accepted', 'rejected'])],
        ]);
        $application = DB::transaction(function () use (
            $farm,
            $farmJobPosting,
            $farmJobApplication,
            $data,
        ): FarmJobApplication {
            $application = FarmJobApplication::query()
                ->whereKey($farmJobApplication->id)
                ->lockForUpdate()
                ->firstOrFail();
            abort_unless($application->status === 'pending', 409, 'This application has already been reviewed.');

            if ($data['status'] === 'accepted') {
                $user = User::query()->whereKey($application->user_id)->lockForUpdate()->firstOrFail();
                abort_unless($user->role === $farmJobPosting->role, 409, 'Applicant role does not match the listing.');
                abort_if($farm->users()->whereKey($user->id)->exists(), 409, 'The applicant already belongs to this farm.');
                $farm->users()->attach($user->id, [
                    'role' => $user->role,
                    'permissions' => null,
                ]);
                $application->update(['status' => 'accepted']);
                $farmJobPosting->update(['status' => 'closed']);
                FarmJobApplication::query()
                    ->where('farm_job_posting_id', $farmJobPosting->id)
                    ->where('status', 'pending')
                    ->where('id', '!=', $application->id)
                    ->update(['status' => 'rejected']);
            } else {
                $application->update(['status' => 'rejected']);
            }

            return $application->fresh()->load('user:id,name,phone,email');
        });

        return response()->json(['data' => $this->applicationData($application)]);
    }

    private function authorizeOwner(Request $request, Farm $farm): void
    {
        abort_unless(
            $request->user()->role === 'farmOwner'
                && $request->user()->farms()->whereKey($farm->id)->exists(),
            403,
            'Only this farm owner can manage job listings.',
        );
    }

    private function postingData(FarmJobPosting $posting): array
    {
        return [
            'id' => (string) $posting->id,
            'farm_id' => (string) $posting->farm_id,
            'farm_name' => $posting->farm?->name,
            'farm_location' => $posting->farm?->location,
            'role' => $posting->role,
            'title' => $posting->title,
            'description' => $posting->description,
            'location' => $posting->location,
            'status' => $posting->status,
            'created_at' => $posting->created_at?->toIso8601String(),
        ];
    }

    private function applicationData(FarmJobApplication $application): array
    {
        return [
            'id' => (string) $application->id,
            'user_id' => (string) $application->user_id,
            'name' => $application->user?->name,
            'phone' => $application->user?->phone,
            'email' => $application->user?->email,
            'message' => $application->message,
            'status' => $application->status,
        ];
    }
}