<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->foreignId('assigned_user_id')->nullable()->after('created_by')->constrained('users')->nullOnDelete();
            $table->index(['farm_id', 'assigned_user_id']);
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->dropForeign(['assigned_user_id']);
            $table->dropIndex(['farm_id', 'assigned_user_id']);
            $table->dropColumn('assigned_user_id');
        });
    }
};
