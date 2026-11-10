<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('animals', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('tag');
            $table->string('type');
            $table->string('sex');
            $table->string('status')->default('active');
            $table->date('birth_date')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->unique(['farm_id', 'tag']);
            $table->index(['farm_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('animals');
    }
};
