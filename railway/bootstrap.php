<?php
// One-off setup after migrations (idempotent, runs on every start):
// - app URL: set from APP_URL while it is still the install default
// - trust Railway's proxy, so HTTPS links and uploads work
// - custom user properties (phone, address, ...) that `app:init` setups seed
// - first administrator from ADMIN_EMAIL / ADMIN_PASSWORD, only while there are no users

declare(strict_types=1);

use App\Models\Role;
use App\Models\Setting;
use App\Models\User;
use App\Providers\SettingsProvider;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\Artisan;

require '/app/vendor/autoload.php';
$app = require '/app/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$log = fn (string $m) => fwrite(STDOUT, "[railway] $m\n");

$appUrl = rtrim((string) getenv('APP_URL'), '/');
$current = Setting::where('key', 'app_url')->whereNull('settingable_type')->value('value');
if ($appUrl !== '' && str_starts_with($appUrl, 'http') && ($current === null || $current === '' || $current === 'http://localhost')) {
    Setting::updateOrCreate(['key' => 'app_url'], ['value' => $appUrl]);
    $log("App URL set to $appUrl (change it later in Admin > Settings).");
}

if (!Setting::where('key', 'trusted_proxies')->whereNull('settingable_type')->exists()) {
    Setting::create(['key' => 'trusted_proxies', 'value' => ['*'], 'type' => 'array']);
    $log('Trusted proxies set to * (Railway proxy).');
}

Artisan::call('db:seed', ['--class' => 'CustomPropertySeeder', '--force' => true]);

if (User::query()->count() === 0) {
    $email = trim((string) getenv('ADMIN_EMAIL'));
    $password = (string) getenv('ADMIN_PASSWORD');
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8) {
        fwrite(STDERR, "[railway] No users yet and ADMIN_EMAIL / ADMIN_PASSWORD are missing or invalid: set them on the Paymenter service and redeploy to create the first admin.\n");
    } else {
        $role = Role::where('name', 'admin')->first();
        User::create([
            'first_name' => (string) (getenv('ADMIN_FIRST_NAME') ?: 'Admin'),
            'last_name' => (string) (getenv('ADMIN_LAST_NAME') ?: 'User'),
            'email' => $email,
            'password' => $password,
            'role_id' => $role?->id,
        ]);
        $log("Created the first administrator $email (password: the ADMIN_PASSWORD variable).");
    }
}

SettingsProvider::flushCache();
