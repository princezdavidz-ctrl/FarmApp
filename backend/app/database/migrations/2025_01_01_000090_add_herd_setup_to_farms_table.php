<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('farms', function (Blueprint $table) {
            $table->unsignedInteger('mother_pig_count')->nullable()->after('invite_code');
            $table->json('piglet_groups')->nullable()->after('mother_pig_count');
            $table->unsignedInteger('pregnant_pig_count')->nullable()->after('piglet_groups');
            $table->string('subscription_plan')->nullable()->after('pregnant_pig_count');
        });
    }

    public function down(): void
    {
        Schema::table('farms', function (Blueprint $table) {
            $table->dropColumn([
                'mother_pig_count',
                'piglet_groups',
                'pregnant_pig_count',
                'subscription_plan',
            ]);
        });
    }
};
