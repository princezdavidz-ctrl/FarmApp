<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_conversations', function (Blueprint $table) {
            $table->foreignId('customer_id')->nullable()->after('app_user_id')->constrained('customers')->nullOnDelete();
            $table->index(['farm_id', 'customer_id', 'last_message_at']);
            $table->unique(['farm_id', 'app_user_id', 'customer_id'], 'support_conversations_farm_user_customer_unique');
        });
    }

    public function down(): void
    {
        Schema::table('support_conversations', function (Blueprint $table) {
            $table->dropUnique('support_conversations_farm_user_customer_unique');
            $table->dropIndex(['farm_id', 'customer_id', 'last_message_at']);
            $table->dropConstrainedForeignId('customer_id');
        });
    }
};
