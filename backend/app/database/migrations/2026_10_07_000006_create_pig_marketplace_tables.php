<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pig_listings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->string('title', 120);
            $table->string('breed', 100);
            $table->unsignedSmallInteger('age_weeks')->nullable();
            $table->decimal('weight_kg', 8, 2)->nullable();
            $table->unsignedInteger('quantity')->default(1);
            $table->decimal('price_per_pig', 12, 2);
            $table->string('currency', 3)->default('KES');
            $table->string('location')->nullable();
            $table->text('description')->nullable();
            $table->string('status')->default('available');
            $table->foreignId('created_by')->constrained('users');
            $table->timestamps();
            $table->index(['status', 'quantity', 'created_at']);
        });

        Schema::create('pig_inquiries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pig_listing_id')->constrained('pig_listings')->cascadeOnDelete();
            $table->string('buyer_name', 120);
            $table->string('phone', 40);
            $table->string('email')->nullable();
            $table->unsignedInteger('quantity');
            $table->text('message')->nullable();
            $table->string('status')->default('pending');
            $table->timestamps();
            $table->index(['pig_listing_id', 'status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pig_inquiries');
        Schema::dropIfExists('pig_listings');
    }
};
