<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('buyer_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('buyer_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('pig_inquiry_id')->nullable()->constrained('pig_inquiries')->cascadeOnDelete();
            $table->foreignId('transport_request_id')->nullable()->constrained('transport_requests')->cascadeOnDelete();
            $table->string('type', 80);
            $table->string('title', 180);
            $table->text('body');
            $table->string('action_route', 255)->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['buyer_user_id', 'read_at', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('buyer_notifications');
    }
};
