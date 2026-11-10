<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('farm_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('recipient_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 80);
            $table->string('title');
            $table->text('body');
            $table->string('severity', 20)->default('info');
            $table->string('related_type', 100)->nullable();
            $table->unsignedBigInteger('related_id')->nullable();
            $table->string('action_route', 255)->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['farm_id', 'recipient_id', 'read_at']);
            $table->index(['farm_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('farm_notifications');
    }
};