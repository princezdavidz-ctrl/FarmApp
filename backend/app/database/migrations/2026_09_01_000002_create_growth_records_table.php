<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('growth_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('animal_id')->constrained('animals')->cascadeOnDelete();
            $table->string('rfid')->nullable();
            $table->double('current_weight');
            $table->double('previous_weight')->nullable();
            $table->double('weight_gain')->nullable();
            $table->double('daily_gain')->nullable();
            $table->integer('age_in_days')->nullable();
            $table->dateTime('measurement_date');
            $table->string('recorded_by')->nullable();
            $table->text('notes')->nullable();
            $table->string('photo_url')->nullable();
            $table->double('target_weight')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['farm_id', 'animal_id']);
            $table->index(['farm_id', 'measurement_date']);
            $table->index(['farm_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('growth_records');
    }
};
