<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained()->cascadeOnDelete();
            $table->string('reference');
            $table->string('status')->default('pending');
            $table->json('items')->nullable();
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->string('currency', 3)->default('KES');
            $table->date('ordered_at');
            $table->date('expected_at')->nullable();
            $table->date('completed_at')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users');
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['farm_id', 'reference']);
            $table->index(['farm_id', 'status', 'ordered_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_orders');
    }
};
