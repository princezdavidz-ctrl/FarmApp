<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('crm_policies')) {
            Schema::create('crm_policies', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
                $table->string('title', 160);
                $table->string('category', 80)->default('All staff');
                $table->string('audience', 32)->default('all');
                $table->string('status', 24)->default('active');
                $table->date('effective_date');
                $table->text('summary');
                $table->text('details')->nullable();
                $table->text('notes')->nullable();
                $table->json('visible_pages');
                $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
                $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamps();
                $table->index(['farm_id', 'status', 'effective_date']);
            });
        }

        if (! Schema::hasTable('crm_audit_logs')) {
            Schema::create('crm_audit_logs', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
                $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
                $table->string('action', 200);
                $table->string('module', 80);
                $table->json('metadata')->nullable();
                $table->timestamps();
                $table->index(['farm_id', 'created_at']);
            });
        }
    }

    public function down(): void
    {
        // This migration only restores tables that were absent; preserve data on rollback.
    }
};
