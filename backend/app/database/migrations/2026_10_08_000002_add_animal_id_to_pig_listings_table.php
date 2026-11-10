<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('pig_listings', 'animal_id')) {
            Schema::table('pig_listings', function (Blueprint $table): void {
                $table->foreignId('animal_id')
                    ->nullable()
                    ->after('farm_id')
                    ->constrained('animals')
                    ->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('pig_listings', 'animal_id')) {
            Schema::table('pig_listings', function (Blueprint $table): void {
                $table->dropConstrainedForeignId('animal_id');
            });
        }
    }
};
