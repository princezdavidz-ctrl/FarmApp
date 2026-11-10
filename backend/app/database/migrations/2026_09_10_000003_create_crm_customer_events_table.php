<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('crm_customer_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type');
            $table->json('data')->nullable();
            $table->dateTime('occurred_at');
            $table->timestamps();

            $table->index(['customer_id', 'occurred_at']);
            $table->index(['customer_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('crm_customer_events');
    }
};
