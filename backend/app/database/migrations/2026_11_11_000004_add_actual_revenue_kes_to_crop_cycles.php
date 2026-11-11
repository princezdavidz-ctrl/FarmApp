<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('crop_cycles', function (Blueprint $table): void {
            $table->decimal('actual_revenue_kes', 14, 2)->nullable()->after('actual_yield_kg');
        });
    }

    public function down(): void
    {
        Schema::table('crop_cycles', function (Blueprint $table): void {
            $table->dropColumn('actual_revenue_kes');
        });
    }
};
