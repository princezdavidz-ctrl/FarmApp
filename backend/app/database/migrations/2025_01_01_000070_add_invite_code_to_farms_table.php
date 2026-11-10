<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('farms', function (Blueprint $table) {
            // Shared with farm managers/workers so they can link their account to this farm at registration.
            $table->string('invite_code', 12)->unique()->nullable()->after('location');
        });
    }

    public function down(): void
    {
        Schema::table('farms', function (Blueprint $table) {
            $table->dropColumn('invite_code');
        });
    }
};
