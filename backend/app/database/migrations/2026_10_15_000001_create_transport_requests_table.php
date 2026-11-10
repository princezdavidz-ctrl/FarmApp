<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transport_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('requester_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('farm_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('supplier_profile_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('driver_profile_id')->nullable()->constrained()->nullOnDelete();
            $table->string('service_type', 20);
            $table->string('vehicle_type', 100);
            $table->decimal('pickup_latitude', 10, 7);
            $table->decimal('pickup_longitude', 10, 7);
            $table->string('pickup_address', 255);
            $table->decimal('destination_latitude', 10, 7);
            $table->decimal('destination_longitude', 10, 7);
            $table->string('destination_address', 255);
            $table->string('load_description', 255)->nullable();
            $table->unsignedSmallInteger('radius_km')->default(25);
            $table->string('status', 20)->default('open');
            $table->timestamps();
            $table->index(['status', 'vehicle_type', 'service_type']);
            $table->index(['requester_user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transport_requests');
    }
};
