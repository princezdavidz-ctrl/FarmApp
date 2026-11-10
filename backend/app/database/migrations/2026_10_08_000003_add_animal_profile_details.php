<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('animals', function (Blueprint $table): void {
            if (! Schema::hasColumn('animals', 'name')) {
                $table->string('name', 100)->nullable();
            }
            if (! Schema::hasColumn('animals', 'is_pregnant')) {
                $table->boolean('is_pregnant')->default(false);
            }
            if (! Schema::hasColumn('animals', 'last_dewormed_at')) {
                $table->date('last_dewormed_at')->nullable();
            }
            if (! Schema::hasColumn('animals', 'last_vaccinated_at')) {
                $table->date('last_vaccinated_at')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('animals', function (Blueprint $table): void {
            $columns = array_filter(
                ['name', 'is_pregnant', 'last_dewormed_at', 'last_vaccinated_at'],
                fn (string $column): bool => Schema::hasColumn('animals', $column),
            );
            if ($columns !== []) {
                $table->dropColumn($columns);
            }
        });
    }
};
