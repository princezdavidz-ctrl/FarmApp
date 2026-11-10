<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'is_global_crm_admin')) {
            Schema::table('users', function (Blueprint $table) {
                $table->boolean('is_global_crm_admin')->default(false)->after('crm_role');
            });
        }

        DB::table('users')->where('email', 'princeinvents@gmail.com')->update(['is_global_crm_admin' => true]);
    }

    public function down(): void
    {
        if (Schema::hasColumn('users', 'is_global_crm_admin')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('is_global_crm_admin');
            });
        }
    }
};
