<?php

namespace Tests\Feature;

use Tests\TestCase;

class RootHealthTest extends TestCase
{
    public function test_root_returns_service_health(): void
    {
        $this->getJson('/')
            ->assertOk()
            ->assertJson([
                'status' => 'ok',
                'service' => 'Farm App',
            ]);
    }
}