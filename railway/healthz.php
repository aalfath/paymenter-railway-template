<?php
// Railway health check: 200 when the database and Redis answer, 503 otherwise.
header('Content-Type: text/plain');
header('Cache-Control: no-store');
try {
    new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s', getenv('DB_HOST'), (int) (getenv('DB_PORT') ?: 3306), getenv('DB_DATABASE')),
        (string) getenv('DB_USERNAME'),
        (string) getenv('DB_PASSWORD'),
        [PDO::ATTR_TIMEOUT => 3]
    );
    $r = new Redis();
    $url = getenv('REDIS_URL');
    if ($url) {
        $u = parse_url($url);
        $r->connect($u['host'], (int) ($u['port'] ?? 6379), 3);
        if (isset($u['pass'])) {
            $r->auth(isset($u['user']) ? [urldecode($u['user']), urldecode($u['pass'])] : urldecode($u['pass']));
        }
    } else {
        $r->connect((string) getenv('REDIS_HOST'), (int) (getenv('REDIS_PORT') ?: 6379), 3);
        $pw = getenv('REDIS_PASSWORD');
        if ($pw && $pw !== 'null') {
            $user = getenv('REDIS_USERNAME');
            $r->auth($user ? [$user, $pw] : $pw);
        }
    }
    $r->ping();
    echo "ok\n";
} catch (Throwable $e) {
    http_response_code(503);
    echo "unavailable\n";
}
