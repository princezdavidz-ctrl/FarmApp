<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('health_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('animal_id')->constrained('animals')->cascadeOnDelete();
            $table->string('type'); // vaccination, treatment, deworming, mortality
            $table->string('status'); // healthy, recovering, critical, deceased
            $table->string('rfid')->nullable();
            $table->json('symptoms')->nullable(); // array of symptoms
            $table->text('diagnosis')->nullable();
            $table->string('medication')->nullable();
            $table->string('dosage')->nullable();
            $table->string('veterinarian')->nullable();
            $table->dateTime('visit_date')->nullable();
            $table->dateTime('next_checkup_date')->nullable();
            $table->text('notes')->nullable();
            $table->json('attachment_urls')->nullable(); // array of image/document URLs
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['farm_id', 'animal_id']);
            $table->index(['farm_id', 'type']);
            $table->index(['farm_id', 'status']);
            $table->index(['farm_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('health_records');
    }
};
