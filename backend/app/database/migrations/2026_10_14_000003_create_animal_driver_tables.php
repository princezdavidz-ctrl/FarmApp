<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('driver_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->uuid('reference')->unique();
            $table->string('driver_license_number', 100)->unique();
            $table->string('county');
            $table->string('service_types');
            $table->string('vehicle_type');
            $table->string('vehicle_registration_number', 30)->unique();
            $table->string('capacity_description', 255);
            $table->string('status')->default('pending');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('review_note')->nullable();
            $table->timestamp('subscription_paid_at')->nullable();
            $table->timestamp('subscription_expires_at')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('available')->default(false);
            $table->timestamp('location_updated_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'available', 'location_updated_at']);
        });

        Schema::create('driver_subscription_plans', function (Blueprint $table) {
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

        Schema::create('driver_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_profile_id')->constrained()->cascadeOnDelete();
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
        Schema::dropIfExists('driver_payments');
        Schema::dropIfExists('driver_subscription_plans');
        Schema::dropIfExists('driver_profiles');
    }
};
