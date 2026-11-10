<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique('users_email_unique');
            $table->dropUnique('users_phone_unique');
            $table->index('email', 'users_email_index');
            $table->index('phone', 'users_phone_index');
        });

        Schema::create('login_otps', function (Blueprint $table): void {
            $table->id();
            $table->uuid('challenge_id')->unique();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('code_hash');
            $table->boolean('remember_me')->default(false);
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamp('expires_at')->index();
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'consumed_at']);
        });

        Schema::table('refresh_tokens', function (Blueprint $table): void {
            $table->boolean('remember_me')->default(false)->after('token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('login_otps');

        Schema::table('refresh_tokens', function (Blueprint $table): void {
            $table->dropColumn('remember_me');
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->dropIndex('users_email_index');
            $table->dropIndex('users_phone_index');
            $table->unique('email');
            $table->unique('phone');
        });
    }
};
