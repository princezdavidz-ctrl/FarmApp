<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;

class UpdateFarmMemberRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'permissions' => ['nullable', 'array'],
            'permissions.*' => ['string', 'in:viewDashboard,manageHerd,manageBreeding,manageFeed,manageFinance,viewSales,manageSales,viewTasks,manageTasks,viewReports,manageSettings,manageMembers,managePolicies,linkFarmManager'],
        ];
    }
}
