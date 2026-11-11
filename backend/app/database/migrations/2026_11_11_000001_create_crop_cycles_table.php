<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('crop_cycles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->string('plot_name', 120);
            $table->string('crop_name', 120);
            $table->string('variety', 120)->nullable();
            $table->decimal('area_acres', 12, 2);
            $table->date('planting_date');
            $table->date('expected_harvest_date')->nullable();
            $table->date('actual_harvest_date')->nullable();
            $table->string('status')->default('planned');
            $table->decimal('expected_yield_kg', 14, 2)->nullable();
            $table->decimal('actual_yield_kg', 14, 2)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['farm_id', 'status', 'planting_date']);
            $table->index(['farm_id', 'expected_harvest_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('crop_cycles');
    }
};
