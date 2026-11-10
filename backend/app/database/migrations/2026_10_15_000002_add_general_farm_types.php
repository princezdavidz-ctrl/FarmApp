<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('farms', function (Blueprint $table): void {
            $table->string('farming_type', 20)->default('mixed');
            $table->json('production_types')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('farms', function (Blueprint $table): void {
            $table->dropColumn(['farming_type', 'production_types']);
        });
    }
};
