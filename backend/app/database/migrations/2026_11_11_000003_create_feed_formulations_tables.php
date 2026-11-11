<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feed_formulations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('name', 120);
            $table->string('target_species', 40)->default('pigs');
            $table->decimal('batch_size_kg', 12, 2);
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['farm_id', 'target_species']);
        });

        Schema::create('feed_formulation_ingredients', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('feed_formulation_id')->constrained()->cascadeOnDelete();
            $table->string('name', 120);
            $table->decimal('inclusion_percent', 6, 3);
            $table->decimal('crude_protein_percent', 6, 3)->nullable();
            $table->decimal('energy_mj_per_kg', 8, 3)->nullable();
            $table->decimal('cost_per_kg', 12, 2)->nullable();
            $table->unsignedSmallInteger('position')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feed_formulation_ingredients');
        Schema::dropIfExists('feed_formulations');
    }
};
