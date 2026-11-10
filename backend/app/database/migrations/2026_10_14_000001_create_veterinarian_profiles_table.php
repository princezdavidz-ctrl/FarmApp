<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('veterinarian_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->uuid('reference')->unique();
            $table->string('license_number', 100)->unique();
            $table->string('clinic_name');
            $table->string('county');
            $table->string('specialization')->nullable();
            $table->unsignedSmallInteger('years_experience')->default(0);
            $table->string('status')->default('pending');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('review_note')->nullable();
            $table->timestamp('subscription_paid_at')->nullable();
            $table->timestamp('subscription_expires_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'created_at']);
        });

        Schema::create('veterinary_subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('amount', 12, 2);
            $table->char('currency', 3)->default('KES');
            $table->unsignedSmallInteger('duration_days')->default(30);
            $table->boolean('active')->default(true);
            $table->timestamps();
        });

        Schema::create('veterinary_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('veterinarian_profile_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('plan_code');
            $table->unsignedSmallInteger('duration_days')->default(30);
            $table->decimal('amount', 12, 2);
            $table->char('currency', 3)->default('KES');
            $table->string('phone', 30);
            $table->string('status')->default('pending');
            $table->string('merchant_request_id')->nullable()->unique();
            $table->string('checkout_request_id')->nullable()->unique();
            $table->string('mpesa_receipt')->nullable()->unique();
            $table->text('result_description')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('veterinary_payments');
        Schema::dropIfExists('veterinary_subscription_plans');
        Schema::dropIfExists('veterinarian_profiles');
    }
};
