<?php

use Illuminate\\Database\\Migrations\\Migration;
use Illuminate\\Database\\Schema\\Blueprint;
use Illuminate\\Support\\Facades\\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transport_requests', function (Blueprint $table) {
            $table->foreignId('pig_inquiry_id')
                ->nullable()
                ->unique()
                ->after('driver_profile_id')
                ->constrained('pig_inquiries')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('transport_requests', function (Blueprint $table) {
            $table->dropConstrainedForeignId('pig_inquiry_id');
        });
    }
};
