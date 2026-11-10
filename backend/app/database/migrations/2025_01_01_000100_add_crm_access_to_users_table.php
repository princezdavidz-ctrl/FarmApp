<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('crm_role')->nullable()->after('role');
            $table->timestamp('crm_closed_at')->nullable()->after('crm_role');
        });

        DB::table('users')->where('role', 'farmOwner')->update(['crm_role' => 'admin']);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['crm_role', 'crm_closed_at']);
        });
    }
};
