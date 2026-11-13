<?php

namespace Shopbench\Native;

/**
 * Writes a single line to the platform log through the Shopbench.Log
 * bridge function. No-op off device.
 */
class PlatformLog
{
    public static function write(string $message): void
    {
        if (function_exists('nativephp_call')) {
            nativephp_call('Shopbench.Log', json_encode(['message' => $message]));
        }
    }
}
