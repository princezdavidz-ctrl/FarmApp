<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veterinary_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('requester_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('veterinarian_profile_id')->nullable()
                ->constrained('veterinarian_profiles')->nullOnDelete();
            $table->string('county', 100);
            $table->string('animal_type', 100);
            $table->string('animal_name', 100)->nullable();
            $table->text('issue_description');
            $table->string('location', 255);
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('status', 20)->default('open');
            $table->timestamps();
            $table->index(['status', 'county', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veterinary_requests');
    }
};
