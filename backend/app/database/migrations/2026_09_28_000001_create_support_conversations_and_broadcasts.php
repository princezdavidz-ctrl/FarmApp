<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('support_conversations')) {
            Schema::create('support_conversations', function (Blueprint $table) {
                $table->id();
                $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
                $table->foreignId('app_user_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('assigned_user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('status', 20)->default('open');
                $table->timestamp('last_message_at')->nullable();
                $table->timestamps();

                $table->unique(['farm_id', 'app_user_id']);
                $table->index(['farm_id', 'status', 'last_message_at']);
            });
        }

        if (! Schema::hasTable('support_messages')) {
            Schema::create('support_messages', function (Blueprint $table) {
                $table->id();
                $table->foreignId('conversation_id')->constrained('support_conversations')->cascadeOnDelete();
                $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('sender_role', 20);
                $table->text('body');
                $table->timestamp('read_at')->nullable();
                $table->timestamps();

                $table->index(['conversation_id', 'created_at']);
                $table->index(['conversation_id', 'sender_role', 'read_at']);
            });
        }

        if (! Schema::hasTable('communication_broadcasts')) {
            Schema::create('communication_broadcasts', function (Blueprint $table) {
                $table->id();
                $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
                $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('recipient_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('audience', 20);
                $table->string('title', 160);
                $table->text('message');
                $table->timestamps();

                $table->index(['farm_id', 'created_at']);
            });
        }

        if (! Schema::hasTable('communication_broadcast_recipients')) {
            Schema::create('communication_broadcast_recipients', function (Blueprint $table) {
                $table->id();
                $table->foreignId('broadcast_id')->constrained('communication_broadcasts')->cascadeOnDelete();
                $table->foreignId('recipient_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('farm_notification_id')->nullable()->constrained('farm_notifications')->nullOnDelete();
                $table->string('push_status', 20)->default('pending');
                $table->timestamp('push_attempted_at')->nullable();
                $table->text('push_error')->nullable();
                $table->timestamps();

                $table->unique(['broadcast_id', 'recipient_id'], 'broadcast_recipients_unique');
                $table->index(['broadcast_id', 'push_status'], 'broadcast_recipients_push_status_idx');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('communication_broadcast_recipients');
        Schema::dropIfExists('communication_broadcasts');
        Schema::dropIfExists('support_messages');
        Schema::dropIfExists('support_conversations');
    }
};
