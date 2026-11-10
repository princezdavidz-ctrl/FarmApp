<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('plan_code');
            $table->unsignedInteger('mother_pig_count');
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
        Schema::dropIfExists('payments');
    }
};