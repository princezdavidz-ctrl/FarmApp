<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\InventoryItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class InventoryControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Farm $farm;

    protected function setUp(): void
    {
        parent::setUp();

        // Create a test user and farm
        $this->user = User::factory()->create(['role' => 'farmOwner']);
        $this->farm = Farm::factory()->create(['created_by' => $this->user->id]);
        $this->farm->users()->attach($this->user->id, ['role' => 'farmOwner']);
    }

    /**
     * Test retrieving all inventory items
     */
    public function test_can_list_inventory_items(): void
    {
        // Create some inventory items
        InventoryItem::factory(3)->create(['farm_id' => $this->farm->id]);

        $response = $this->actingAs($this->user)
            ->getJson("/api/v1/farms/{$this->farm->id}/inventory/items");

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'data' => [
                '*' => [
                    'id',
                    'name',
                    'category',
                    'sku',
                    'quantity',
                    'unit',
                    'supplier',
                    'totalValue',
                    'stockStatus',
                ]
            ],
            'summary' => [
                'totalItems',
                'lowStockItems',
                'expiringItems',
                'inventoryValue',
            ]
        ]);
    }

    /**
     * Test creating an inventory item
     */
    public function test_can_create_inventory_item(): void
    {
        $data = [
            'name' => 'Grower Feed',
            'category' => 'Feed',
            'sku' => 'INV-00124',
            'barcode' => 'BAR-00124',
            'quantity' => 520,
            'unit' => 'kg',
            'minimumLevel' => 100,
            'costPrice' => 3200,
            'supplier' => 'Unga Farm Care',
            'expiryDate' => now()->addMonths(3)->toDateTimeString(),
            'storageLocation' => 'Store A',
            'notes' => 'Initial stock',
        ];

        $response = $this->actingAs($this->user)
            ->postJson("/api/v1/farms/{$this->farm->id}/inventory/items", $data);

        $response->assertStatus(201);
        $response->assertJsonFragment([
            'name' => 'Grower Feed',
            'category' => 'Feed',
            'sku' => 'INV-00124',
        ]);

        $this->assertDatabaseHas('inventory_items', [
            'farm_id' => $this->farm->id,
            'name' => 'Grower Feed',
            'sku' => 'INV-00124',
        ]);

        $this->assertDatabaseHas('inventory_movements', [
            'type' => 'stock_in',
            'quantity' => 520,
        ]);
    }

    /**
     * Test retrieving a single inventory item with movements
     */
    public function test_can_show_inventory_item(): void
    {
        $item = InventoryItem::factory()->create(['farm_id' => $this->farm->id, 'created_by' => $this->user->id]);
        $item->movements()->create([
            'type' => 'stock_in',
            'quantity' => 100,
            'recorded_by' => $this->user->id,
        ]);

        $response = $this->actingAs($this->user)
            ->getJson("/api/v1/farms/{$this->farm->id}/inventory/items/{$item->id}");

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'item' => [
                'id',
                'name',
                'category',
                'sku',
                'quantity',
                'unit',
                'isLowStock',
                'isExpired',
                'isExpiringSoon',
                'stockStatus',
                'totalValue',
            ],
            'movements' => [
                '*' => [
                    'id',
                    'type',
                    'quantity',
                    'movementLabel',
                    'createdAt',
                ]
            ]
        ]);
    }

    /**
     * Test updating an inventory item
     */
    public function test_can_update_inventory_item(): void
    {
        $item = InventoryItem::factory()->create(['farm_id' => $this->farm->id]);

        $data = [
            'name' => 'Updated Feed',
            'quantity' => 750,
            'minimumLevel' => 150,
            'supplier' => 'New Supplier',
        ];

        $response = $this->actingAs($this->user)
            ->patchJson("/api/v1/farms/{$this->farm->id}/inventory/items/{$item->id}", $data);

        $response->assertStatus(200);
        $this->assertDatabaseHas('inventory_items', [
            'id' => $item->id,
            'name' => 'Updated Feed',
            'quantity' => 750,
        ]);
    }

    /**
     * Test recording stock movement
     */
    public function test_can_record_stock_movement(): void
    {
        $item = InventoryItem::factory()->create(['farm_id' => $this->farm->id, 'created_by' => $this->user->id]);

        $data = [
            'type' => 'stock_out',
            'quantity' => 50,
            'reference' => 'USAGE-001',
            'notes' => 'Fed to pigs',
        ];

        $response = $this->actingAs($this->user)
            ->postJson("/api/v1/farms/{$this->farm->id}/inventory/items/{$item->id}/movements", $data);

        $response->assertStatus(201);
        $this->assertDatabaseHas('inventory_movements', [
            'inventory_item_id' => $item->id,
            'type' => 'stock_out',
            'quantity' => 50,
        ]);
    }

    /**
     * Test getting inventory alerts
     */
    public function test_can_get_inventory_alerts(): void
    {
        // Create items with different alert conditions
        InventoryItem::factory()->create([
            'farm_id' => $this->farm->id,
            'quantity' => 50,
            'minimum_level' => 100,
        ]);

        InventoryItem::factory()->create([
            'farm_id' => $this->farm->id,
            'quantity' => 100,
            'expiry_date' => now()->addDays(3),
        ]);

        InventoryItem::factory()->create([
            'farm_id' => $this->farm->id,
            'quantity' => 100,
            'expiry_date' => now()->subDays(1),
        ]);

        $response = $this->actingAs($this->user)
            ->getJson("/api/v1/farms/{$this->farm->id}/inventory/alerts");

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'lowStock' => [
                '*' => [
                    'id',
                    'name',
                    'quantity',
                    'minimumLevel',
                ]
            ],
            'expiring' => [
                '*' => ['id', 'name', 'expiryDate']
            ],
            'expired' => [
                '*' => ['id', 'name', 'expiryDate']
            ]
        ]);
    }

    /**
     * Test filtering by category
     */
    public function test_can_filter_by_category(): void
    {
        InventoryItem::factory()->create(['farm_id' => $this->farm->id, 'category' => 'Feed']);
        InventoryItem::factory(2)->create(['farm_id' => $this->farm->id, 'category' => 'Medicine']);

        $response = $this->actingAs($this->user)
            ->getJson("/api/v1/farms/{$this->farm->id}/inventory/by-category?category=Medicine");

        $response->assertStatus(200);
        $response->assertJsonPath('count', 2);
    }

    /**
     * Test deleting an inventory item
     */
    public function test_can_delete_inventory_item(): void
    {
        $item = InventoryItem::factory()->create(['farm_id' => $this->farm->id]);

        $response = $this->actingAs($this->user)
            ->deleteJson("/api/v1/farms/{$this->farm->id}/inventory/items/{$item->id}");

        $response->assertStatus(204);
        $this->assertDatabaseMissing('inventory_items', ['id' => $item->id]);
    }

    /**
     * Test unauthorized access
     */
    public function test_cannot_access_other_farms_inventory(): void
    {
        $otherUser = User::factory()->create(['role' => 'farmOwner']);
        $otherFarm = Farm::factory()->create(['created_by' => $otherUser->id]);

        $response = $this->actingAs($this->user)
            ->getJson("/api/v1/farms/{$otherFarm->id}/inventory/items");

        $response->assertStatus(403);
    }
}
