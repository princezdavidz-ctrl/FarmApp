<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmAuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CrmAuditLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);
        $farmId = $request->integer('farm_id');
        $this->authorizeFarm($request, $farmId);

        $logs = CrmAuditLog::query()
            ->where('farm_id', $farmId)
            ->with('user:id,name,email')
            ->latest()
            ->limit(min(max($request->integer('per_page', 50), 1), 100))
            ->get()
            ->map(fn (CrmAuditLog $log): array => $this->serialize($log));

        return response()->json(['data' => $logs]);
    }

    private function serialize(CrmAuditLog $log): array
    {
        return [
            'id' => (string) $log->id,
            'staff' => $log->user?->name ?? $log->user?->email ?? 'Former CRM user',
            'action' => $log->action,
            'module' => $log->module,
            'metadata' => $log->metadata ?? [],
            'at' => $log->created_at?->toIso8601String(),
        ];
    }

    private function authorizeAdmin(Request $request): void
    {
        if (($request->user()->crm_role ?? null) !== 'admin' && $request->user()->role !== 'farmOwner') {
            abort(403, 'Only CRM admins can view staff audit logs.');
        }
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        if (! $request->user()->farms()->whereKey($farmId)->exists()) {
            abort(403, 'You do not have access to this farm.');
        }
    }
}
