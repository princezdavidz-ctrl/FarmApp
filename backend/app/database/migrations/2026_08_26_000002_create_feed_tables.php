<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feed_stocks', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('name');
            $table->decimal('quantity', 12, 2);
            $table->string('unit', 20)->default('bags');
            $table->string('location')->nullable();
            $table->timestamps();
            $table->index(['farm_id', 'name']);
        });

        Schema::create('feed_usages', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('feed_stock_id')->nullable()->constrained('feed_stocks')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->decimal('quantity', 12, 2);
            $table->string('unit', 20)->default('bags');
            $table->dateTime('used_at');
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['farm_id', 'used_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feed_usages');
        Schema::dropIfExists('feed_stocks');
    }
};
