<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'phone')) {
            Schema::table('users', function (Blueprint $table): void {
                $table->string('phone', 30)->nullable()->after('email');
                $table->index('phone', 'users_phone_index');
            });
        }

        if (! Schema::hasColumn('farms', 'invite_code')) {
            Schema::table('farms', function (Blueprint $table): void {
                $table->string('invite_code', 12)->nullable()->unique()->after('location');
            });
        }

        $missingFarmColumns = array_values(array_filter(
            ['mother_pig_count', 'piglet_groups', 'pregnant_pig_count'],
            fn (string $column): bool => ! Schema::hasColumn('farms', $column),
        ));

        if ($missingFarmColumns !== []) {
            Schema::table('farms', function (Blueprint $table) use ($missingFarmColumns): void {
                foreach ($missingFarmColumns as $column) {
                    if ($column === 'piglet_groups') {
                        $table->json($column)->nullable();
                    } else {
                        $table->unsignedInteger($column)->nullable();
                    }
                }
            });
        }

        if (Schema::hasTable('farm_user')) {
            if (! Schema::hasColumn('farm_user', 'permissions')) {
                Schema::table('farm_user', function (Blueprint $table): void {
                    $table->json('permissions')->nullable();
                });
            }

            if (! Schema::hasColumn('farm_user', 'role')) {
                Schema::table('farm_user', function (Blueprint $table): void {
                    $table->string('role', 30)->nullable();
                });
            }
        }
    }

    public function down(): void
    {
        // This migration only repairs missing columns; rolling it back could remove existing data.
    }
};
