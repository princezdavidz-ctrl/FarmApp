<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('buyers', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->timestamps();
        });

        DB::table('users')
            ->where('role', 'buyer')
            ->select('id', 'created_at', 'updated_at')
            ->orderBy('id')
            ->chunkById(500, function ($users): void {
                foreach ($users as $user) {
                    DB::table('buyers')->insertOrIgnore([
                        'user_id' => $user->id,
                        'created_at' => $user->created_at,
                        'updated_at' => $user->updated_at,
                    ]);
                }
            });

        Schema::table('pig_inquiries', function (Blueprint $table): void {
            $table->foreignId('buyer_id')
                ->nullable()
                ->after('buyer_user_id')
                ->constrained('buyers')
                ->nullOnDelete();
            $table->index(['buyer_id', 'created_at']);
        });

        DB::table('pig_inquiries')
            ->whereNotNull('buyer_user_id')
            ->orderBy('id')
            ->chunkById(500, function ($inquiries): void {
                foreach ($inquiries as $inquiry) {
                    $buyerId = DB::table('buyers')
                        ->where('user_id', $inquiry->buyer_user_id)
                        ->value('id');
                    if ($buyerId !== null) {
                        DB::table('pig_inquiries')
                            ->where('id', $inquiry->id)
                            ->update(['buyer_id' => $buyerId]);
                    }
                }
            });
    }

    public function down(): void
    {
        Schema::table('pig_inquiries', function (Blueprint $table): void {
            $table->dropIndex(['buyer_id', 'created_at']);
            $table->dropConstrainedForeignId('buyer_id');
        });

        Schema::dropIfExists('buyers');
    }
};
