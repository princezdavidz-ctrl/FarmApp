<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('animals', 'weight_kg')) {
            Schema::table('animals', function (Blueprint $table): void {
                $table->decimal('weight_kg', 8, 2)->nullable();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('animals', 'weight_kg')) {
            Schema::table('animals', function (Blueprint $table): void {
                $table->dropColumn('weight_kg');
            });
        }
    }
};
