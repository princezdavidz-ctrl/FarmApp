<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('crop_cycles', function (Blueprint $table) {
            $table->foreignId('crop_plot_id')
                ->nullable()
                ->after('farm_id')
                ->constrained('crop_plots')
                ->nullOnDelete();
            $table->index(['farm_id', 'crop_plot_id']);
        });
    }

    public function down(): void
    {
        Schema::table('crop_cycles', function (Blueprint $table) {
            $table->dropForeign(['crop_plot_id']);
            $table->dropIndex(['farm_id', 'crop_plot_id']);
            $table->dropColumn('crop_plot_id');
        });
    }
};
