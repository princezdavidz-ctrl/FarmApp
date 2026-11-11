<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Farm;
use App\Models\FeedFormulation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FeedFormulationController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFeedAccess($request, $farm);
        $items = $farm->feedFormulations()->with('ingredients')->latest()->get();

        return response()->json(['data' => $items->map(fn (FeedFormulation $item) => $this->serialize($item))]);
    }

    public function store(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFeedAccess($request, $farm);
        $data = $this->validatedData($request);
        $this->assertPercentages($data['ingredients']);

        $formulation = DB::transaction(function () use ($farm, $request, $data): FeedFormulation {
            $formulation = $farm->feedFormulations()->create([
                'created_by' => $request->user()->id,
                'name' => $data['name'],
                'target_species' => $data['target_species'],
                'batch_size_kg' => $data['batch_size_kg'],
                'notes' => $data['notes'] ?? null,
            ]);
            $formulation->ingredients()->createMany(
                collect($data['ingredients'])->values()->map(fn (array $item, int $index) => $item + ['position' => $index])->all()
            );

            return $formulation->load('ingredients');
        });

        return response()->json(['data' => $this->serialize($formulation)], 201);
    }

    public function destroy(Request $request, Farm $farm, FeedFormulation $feedFormulation): JsonResponse
    {
        abort_if((int) $feedFormulation->farm_id !== (int) $farm->id, 404);
        $this->authorizeFeedAccess($request, $farm);
        $feedFormulation->delete();

        return response()->json(null, 204);
    }

    private function validatedData(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'target_species' => ['required', 'in:pigs,cattle,poultry,goats,sheep,rabbits,other'],
            'batch_size_kg' => ['required', 'numeric', 'gt:0', 'max:1000000'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'ingredients' => ['required', 'array', 'min:2', 'max:30'],
            'ingredients.*.name' => ['required', 'string', 'max:120'],
            'ingredients.*.inclusion_percent' => ['required', 'numeric', 'gt:0', 'max:100'],
            'ingredients.*.crude_protein_percent' => ['nullable', 'numeric', 'between:0,100'],
            'ingredients.*.energy_mj_per_kg' => ['nullable', 'numeric', 'between:0,100'],
            'ingredients.*.cost_per_kg' => ['nullable', 'numeric', 'gte:0', 'max:1000000'],
        ]);
    }

    private function assertPercentages(array $ingredients): void
    {
        $total = array_sum(array_map(fn (array $item): float => (float) $item['inclusion_percent'], $ingredients));
        if (abs($total - 100) > 0.01) {
            throw ValidationException::withMessages([
                'ingredients' => ['Ingredient inclusion percentages must add up to 100%.'],
            ]);
        }
    }

    private function serialize(FeedFormulation $item): array
    {
        $ingredients = $item->ingredients;
        $protein = $ingredients->every(fn ($ingredient) => $ingredient->crude_protein_percent !== null)
            ? $ingredients->sum(fn ($ingredient) => (float) $ingredient->inclusion_percent * (float) $ingredient->crude_protein_percent / 100)
            : null;
        $energy = $ingredients->every(fn ($ingredient) => $ingredient->energy_mj_per_kg !== null)
            ? $ingredients->sum(fn ($ingredient) => (float) $ingredient->inclusion_percent * (float) $ingredient->energy_mj_per_kg / 100)
            : null;
        $cost = $ingredients->every(fn ($ingredient) => $ingredient->cost_per_kg !== null)
            ? $ingredients->sum(fn ($ingredient) => (float) $ingredient->inclusion_percent * (float) $ingredient->cost_per_kg / 100)
            : null;

        return [
            'id' => (string) $item->id,
            'name' => $item->name,
            'target_species' => $item->target_species,
            'batch_size_kg' => (float) $item->batch_size_kg,
            'notes' => $item->notes,
            'estimated_crude_protein_percent' => $protein === null ? null : round($protein, 2),
            'estimated_energy_mj_per_kg' => $energy === null ? null : round($energy, 2),
            'estimated_cost_per_kg' => $cost === null ? null : round($cost, 2),
            'ingredients' => $ingredients->map(fn ($ingredient) => [
                'name' => $ingredient->name,
                'inclusion_percent' => (float) $ingredient->inclusion_percent,
                'crude_protein_percent' => $ingredient->crude_protein_percent === null ? null : (float) $ingredient->crude_protein_percent,
                'energy_mj_per_kg' => $ingredient->energy_mj_per_kg === null ? null : (float) $ingredient->energy_mj_per_kg,
                'cost_per_kg' => $ingredient->cost_per_kg === null ? null : (float) $ingredient->cost_per_kg,
                'batch_quantity_kg' => round((float) $item->batch_size_kg * (float) $ingredient->inclusion_percent / 100, 2),
            ])->values(),
            'created_at' => $item->created_at?->toIso8601String(),
        ];
    }

    private function authorizeFeedAccess(Request $request, Farm $farm): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($user->crm_closed_at !== null, 403, 'This account is inactive.');
        if ($user->role === 'farmOwner' || in_array($user->crm_role, ['admin', 'finance'], true)) return;
        $permissions = $membership->pivot->permissions === null
            ? match ($user->role) {
                'farmManager', 'farmWorker' => ['manageFeed'],
                default => [],
            }
            : json_decode($membership->pivot->permissions, true);
        abort_unless(in_array('manageFeed', $permissions ?? [], true), 403, 'You do not have permission to manage feed formulations.');
    }
}
