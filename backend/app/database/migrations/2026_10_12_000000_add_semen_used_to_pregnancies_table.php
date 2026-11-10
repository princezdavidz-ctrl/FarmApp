<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pregnancies', function (Blueprint $table) {
            $table->string('semen_used')->nullable()->after('mating_date');
        });
    }

    public function down(): void
    {
        Schema::table('pregnancies', function (Blueprint $table) {
            $table->dropColumn('semen_used');
        });
    }
};
