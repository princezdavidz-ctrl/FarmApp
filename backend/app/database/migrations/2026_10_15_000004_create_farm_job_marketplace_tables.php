<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('farm_job_postings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->string('role', 20);
            $table->string('title', 150);
            $table->text('description');
            $table->string('location', 255)->nullable();
            $table->string('status', 20)->default('open');
            $table->timestamps();
            $table->index(['status', 'role', 'created_at']);
        });

        Schema::create('farm_job_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_job_posting_id')
                ->constrained('farm_job_postings')
                ->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('message')->nullable();
            $table->string('status', 20)->default('pending');
            $table->timestamps();
            $table->unique(['farm_job_posting_id', 'user_id']);
            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('farm_job_applications');
        Schema::dropIfExists('farm_job_postings');
    }
};