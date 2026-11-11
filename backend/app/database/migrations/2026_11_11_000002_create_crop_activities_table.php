<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('crop_activities', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('crop_cycle_id')->nullable()->constrained('crop_cycles')->nullOnDelete();
            $table->string('activity_type', 40);
            $table->date('activity_date');
            $table->string('title', 160);
            $table->string('product_name', 160)->nullable();
            $table->decimal('quantity', 14, 3)->nullable();
            $table->string('unit', 40)->nullable();
            $table->decimal('cost', 14, 2)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['farm_id', 'activity_date']);
            $table->index(['farm_id', 'activity_type', 'activity_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('crop_activities');
    }
};
