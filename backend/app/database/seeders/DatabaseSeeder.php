<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Farm;
use App\Models\SubscriptionPlan;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $tester = User::where('email', 'test@example.com')->first();
        if (config('app.env') === 'production') {
            $tester?->delete();
        } else {
            $user = User::updateOrCreate(['email' => 'test@example.com'], [
                'name' => 'Test User',
                'password' => Hash::make('password'),
                'role' => 'farmOwner',
                'crm_role' => 'admin',
            ]);

            $farm = Farm::firstOrCreate([
                'name' => 'Green Valley Farm',
            ], [
                'location' => 'Kenya',
            ]);

            $user->farms()->syncWithoutDetaching([$farm->id]);
        }

        foreach ([
            ['code' => 'starter', 'name' => 'Starter', 'description' => 'For small farms getting started.', 'amount' => 10, 'currency' => 'KES', 'pig_limit' => 50],
            ['code' => 'growth', 'name' => 'Growth', 'description' => 'For growing teams and herds.', 'amount' => 25, 'currency' => 'KES', 'pig_limit' => 250],
            ['code' => 'enterprise', 'name' => 'Enterprise', 'description' => 'For large or multi-farm operations.', 'amount' => 60, 'currency' => 'KES', 'pig_limit' => null],
        ] as $plan) {
            SubscriptionPlan::updateOrCreate(['code' => $plan['code']], $plan + ['active' => true]);
        }
    }
}
