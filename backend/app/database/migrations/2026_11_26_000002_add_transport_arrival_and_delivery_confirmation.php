<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transport_requests', function (Blueprint $table) {
            $table->timestamp('arrived_at')->nullable()->after('status');
            $table->timestamp('completed_at')->nullable()->after('arrived_at');
            $table->text('delivery_confirmation')->nullable()->after('completed_at');
        });
    }

    public function down(): void
    {
        Schema::table('transport_requests', function (Blueprint $table) {
            $table->dropColumn(['arrived_at', 'completed_at', 'delivery_confirmation']);
        });
    }
};
