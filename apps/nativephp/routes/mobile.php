<?php

use App\NativeComponents\Shell;
use Illuminate\Support\Facades\Route;

// One native screen hosts the whole app (tab stacks are managed in Shell).
Route::native('/', Shell::class);
