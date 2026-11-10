<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pregnancies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sow_id')->constrained('animals')->cascadeOnDelete();
            $table->foreignId('boar_id')->nullable()->constrained('animals')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->date('mating_date');
            $table->date('confirmation_date')->nullable();
            $table->date('expected_farrowing_date');
            $table->date('actual_farrowing_date')->nullable();
            $table->string('status')->default('suspected');
            $table->unsignedInteger('expected_litter_size')->nullable();
            $table->unsignedInteger('born_alive')->nullable();
            $table->unsignedInteger('stillborn')->nullable();
            $table->unsignedInteger('mummified')->nullable();
            $table->unsignedInteger('weaned')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['farm_id', 'status']);
            $table->index(['farm_id', 'expected_farrowing_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pregnancies');
    }
};