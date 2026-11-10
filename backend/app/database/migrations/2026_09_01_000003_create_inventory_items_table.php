<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('inventory_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->enum('category', ['Feed', 'Medicine', 'Vaccines', 'Equipment', 'Cleaning', 'RFID', 'Other']);
            $table->string('sku')->unique();
            $table->string('barcode')->nullable()->unique();
            $table->decimal('quantity', 10, 2);
            $table->string('unit')->default('kg'); // kg, bottles, pieces, liters, etc.
            $table->decimal('minimum_level', 10, 2)->default(0);
            $table->decimal('cost_price', 10, 2)->default(0);
            $table->string('supplier')->nullable();
            $table->timestamp('expiry_date')->nullable();
            $table->string('storage_location')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
            
            $table->index('farm_id');
            $table->index('category');
            $table->index('sku');
        });

        Schema::create('inventory_movements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('inventory_item_id')->constrained('inventory_items')->cascadeOnDelete();
            $table->enum('type', ['stock_in', 'stock_out', 'adjustment', 'expired']);
            $table->decimal('quantity', 10, 2);
            $table->string('reference')->nullable(); // e.g., PO number, order ID
            $table->text('notes')->nullable();
            $table->foreignId('recorded_by')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
            
            $table->index('inventory_item_id');
            $table->index('type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_movements');
        Schema::dropIfExists('inventory_items');
    }
};
