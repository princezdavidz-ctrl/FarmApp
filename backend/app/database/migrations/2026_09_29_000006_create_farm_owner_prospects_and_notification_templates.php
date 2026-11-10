<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('farm_owner_prospects')) {
            Schema::create('farm_owner_prospects', function (Blueprint $table) {
                $table->id();
                $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
                $table->string('owner_name');
                $table->string('email')->nullable();
                $table->string('phone', 30)->nullable();
                $table->string('farm_name');
                $table->string('status', 30)->default('new');
                $table->text('notes')->nullable();
                $table->timestamps();
                $table->index(['status', 'created_at']);
                $table->index(['farm_name', 'status']);
            });
        }

        if (! Schema::hasTable('crm_notification_templates')) {
            Schema::create('crm_notification_templates', function (Blueprint $table) {
                $table->id();
                $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
                $table->string('title', 160);
                $table->string('message', 1000);
                $table->boolean('active')->default(true);
                $table->timestamps();
                $table->index(['active', 'title']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('crm_notification_templates');
        Schema::dropIfExists('farm_owner_prospects');
    }
};
