<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feed_reminders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('schedule_id', 100);
            $table->string('name', 120);
            $table->unsignedSmallInteger('minutes_after_midnight');
            $table->string('timezone', 64);
            $table->boolean('enabled')->default(true);
            $table->date('last_sent_on')->nullable();
            $table->timestamps();

            $table->unique(['farm_id', 'user_id', 'schedule_id']);
            $table->index(['enabled', 'minutes_after_midnight']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feed_reminders');
    }
};
