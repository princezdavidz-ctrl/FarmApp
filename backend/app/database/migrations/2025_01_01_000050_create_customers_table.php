<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('name');
            $table->string('email')->nullable();
            $table->string('phone')->nullable();
            $table->string('company')->nullable();
            $table->string('address')->nullable();
            $table->string('type')->default('lead');
            $table->string('status')->default('new');
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['farm_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
