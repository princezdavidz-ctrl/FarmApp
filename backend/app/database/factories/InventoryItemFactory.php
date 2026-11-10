<?php

namespace Database\Factories;

use App\Models\Farm;
use App\Models\InventoryItem;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<InventoryItem>
 */
class InventoryItemFactory extends Factory
{
    protected $model = InventoryItem::class;

    public function definition(): array
    {
        return [
            'farm_id' => Farm::factory(),
            'name' => $this->faker->words(3, true),
            'category' => $this->faker->randomElement(['Feed', 'Medicine', 'Vaccines', 'Equipment', 'Cleaning', 'RFID', 'Other']),
            'sku' => 'INV-' . $this->faker->unique()->numberBetween(100, 99999),
            'barcode' => null,
            'quantity' => $this->faker->randomFloat(2, 100, 5000),
            'unit' => $this->faker->randomElement(['kg', 'liters', 'bottles', 'pieces']),
            'minimum_level' => $this->faker->randomFloat(2, 10, 100),
            'cost_price' => $this->faker->randomFloat(2, 100, 5000),
            'supplier' => $this->faker->company(),
            'expiry_date' => $this->faker->optional()->dateTimeBetween('now', '+6 months'),
            'storage_location' => $this->faker->randomElement(['Store A', 'Store B', 'Warehouse', 'Shed']),
            'notes' => $this->faker->optional()->text(100),
            'created_by' => User::factory(),
        ];
    }
}
