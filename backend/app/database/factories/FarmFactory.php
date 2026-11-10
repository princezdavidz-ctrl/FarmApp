<?php

namespace Database\Factories;

use App\Models\Farm;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Farm>
 */
class FarmFactory extends Factory
{
    protected $model = Farm::class;

    public function definition(): array
    {
        return [
            'name' => $this->faker->company() . ' Farm',
            'location' => $this->faker->city(),
            'invite_code' => $this->faker->unique()->bothify('????####'),
        ];
    }
}
