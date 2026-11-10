<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('farms') && ! Schema::hasColumn('farms', 'subscription_plan')) {
            Schema::table('farms', function (Blueprint $table): void {
                $table->string('subscription_plan')->nullable();
            });
        }
    }

    public function down(): void
    {
        // This migration only repairs missing schema; rolling it back could remove existing data.
    }
};
