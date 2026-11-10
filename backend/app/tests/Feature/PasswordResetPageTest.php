<?php

namespace Tests\Feature;

use Tests\TestCase;

class PasswordResetPageTest extends TestCase
{
    public function test_reset_page_accepts_token_and_email_from_query_parameters(): void
    {
        $this->get('/reset-password?token=test-reset-token&email=farmer%40example.com')
            ->assertOk()
            ->assertSee('name="token" value="test-reset-token"', false)
            ->assertSee('value="farmer@example.com"', false);
    }

    public function test_reset_page_still_accepts_token_in_path(): void
    {
        $this->get('/reset-password/test-reset-token?email=farmer%40example.com')
            ->assertOk()
            ->assertSee('name="token" value="test-reset-token"', false);
    }
}
