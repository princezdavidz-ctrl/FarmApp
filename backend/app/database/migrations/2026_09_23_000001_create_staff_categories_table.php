<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('staff_categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('farm_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('slug');
            $table->string('icon')->default('•');
            $table->string('color')->default('#286846');
            $table->boolean('active')->default(true);
            $table->timestamps();
            $table->unique(['farm_id', 'slug']);
        });

        $now = now();
        $defaults = [];
        foreach (DB::table('farms')->pluck('id') as $farmId) {
            foreach ([['Finance', '₿', '#286846'], ['Customer service', '✦', '#5b9c98']] as [$name, $icon, $color]) {
                $defaults[] = ['farm_id' => $farmId, 'name' => $name, 'slug' => \Illuminate\Support\Str::slug($name), 'icon' => $icon, 'color' => $color, 'active' => true, 'created_at' => $now, 'updated_at' => $now];
            }
        }
        if ($defaults) DB::table('staff_categories')->insert($defaults);
    }

    public function down(): void
    {
        Schema::dropIfExists('staff_categories');
    }
};
