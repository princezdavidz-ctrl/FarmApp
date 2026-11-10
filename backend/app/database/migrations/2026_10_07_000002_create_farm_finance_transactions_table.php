<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('farm_finance_transactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 16);
            $table->string('category', 80);
            $table->string('description', 255);
            $table->decimal('amount', 12, 2);
            $table->char('currency', 3)->default('KES');
            $table->date('occurred_at');
            $table->timestamps();
            $table->index(['farm_id', 'occurred_at']);
            $table->index(['farm_id', 'type', 'occurred_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('farm_finance_transactions');
    }
};
