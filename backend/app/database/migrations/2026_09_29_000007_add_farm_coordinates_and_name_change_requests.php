<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('farms', function (Blueprint $table): void {
            $table->decimal('latitude', 10, 7)->nullable()->after('location');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
        });

        Schema::create('farm_name_change_requests', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->foreignId('requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('current_name');
            $table->string('requested_name');
            $table->string('status', 20)->default('pending');
            $table->text('review_notes')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
            $table->index(['farm_id', 'status']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('farm_name_change_requests');
        Schema::table('farms', function (Blueprint $table): void {
            $table->dropColumn(['latitude', 'longitude']);
        });
    }
};
