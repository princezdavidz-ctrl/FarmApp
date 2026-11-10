<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('farm_user', function (Blueprint $table) {
            // Null means "use the role's default permission set" (see RolePermissions on the Flutter side).
            // Set by the farm owner to override a member's default permissions for this farm.
            $table->json('permissions')->nullable()->after('user_id');
        });
    }

    public function down(): void
    {
        Schema::table('farm_user', function (Blueprint $table) {
            $table->dropColumn('permissions');
        });
    }
};
