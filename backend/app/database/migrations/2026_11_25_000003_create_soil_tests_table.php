<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('soil_tests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('crop_plot_id')->constrained()->cascadeOnDelete();
            $table->date('sampled_at');
            $table->string('laboratory_name', 160)->nullable();
            $table->decimal('ph', 4, 2)->nullable();
            $table->decimal('nitrogen_ppm', 10, 2)->nullable();
            $table->decimal('phosphorus_ppm', 10, 2)->nullable();
            $table->decimal('potassium_ppm', 10, 2)->nullable();
            $table->decimal('organic_matter_percent', 5, 2)->nullable();
            $table->decimal('moisture_percent', 5, 2)->nullable();
            $table->text('recommendations')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['crop_plot_id', 'sampled_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('soil_tests');
    }
};
