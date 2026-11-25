<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('crop_plots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->string('name', 120);
            $table->decimal('area_acres', 12, 2);
            $table->string('soil_type', 80)->nullable();
            $table->string('irrigation_source', 100)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('status', 20)->default('active');
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->unique(['farm_id', 'name']);
            $table->index(['farm_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('crop_plots');
    }
};
