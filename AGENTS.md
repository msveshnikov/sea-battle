# AGENTS.md — Sea Battle 3D (Морской бой)

## Where everything lives
- GitHub (public): https://github.com/msveshnikov/sea-battle — releases carry SeaBattle.exe + SeaBattle.apk (site links to releases/latest/download/SeaBattle.exe).
- Site card: maxims.top index.html (source C:\My-progs\Godot\maxims), image img/seabattle.jpg.
- Project: `C:\My-progs\Godot\seabattle` (Godot 4.7 project in the root; old Cordova game in `legacy/`, git-ignored keystore there).
- Live web build: https://maxims.top/seabattle/ → server `ubuntu@severance.lol:/var/www/maxims/seabattle/`
- APK: https://maxims.top/seabattle/SeaBattle.apk (debug-signed, package `com.maxsoft.seabattle`, version 2.0.1 / code 20001).
- Multiplayer relay: `wss://severance.lol/village-ws` (shared with Gacha Village; source `C:\My-progs\Godot\village\server`). Rooms: `seabattle-quick-<mode>`, `seabattle-room-<CODE>`.
- Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`
- Godot 4.7.2: `C:\Users\msves\OneDrive\Рабочий стол\Godot_v4.7.2-stable_win64.exe`
- Concept art: `concept/` (ChatGPT chat "Generate Naval Game Art" holds the style reference).
- Save file: `user://settings.cfg` (Windows: `%APPDATA%\Godot\app_userdata\Sea Battle\`).

- Google Play: app «Sea Battle 3D: Fleet Online» / «Морской бой 3D: флот онлайн», package com.maxsoft.seabattle, Play Console app id 4975254520482593102 (dev 5957945224586801272). Upload key = the old Cordova key: `~/.android/seabattle-upload.jks` (alias my-key-alias, password in seabattle-upload.txt beside it; same SHA1 29:92:C3:… as legacy/signing.keystore). Godot reads it from `.godot/export_credentials.cfg` (preset.3, not in git). AAB preset «Android Play» → build/play/SeaBattle.aab (Gradle, target SDK 36, v7a+arm64+x86_64; needs `android/` build template, git-ignored). Bump version/code in BOTH Android presets.
- Store: texts store/listing.md, graphics `python scripts/tools/play_store.py` → renders/play (shots from `-- --autotest --shots-only --lang=ru|en --mood=… --resolution 1920x1080`), privacy https://maxims.top/seabattle/privacy.html (store/privacy.html). Icon, banners and title screenshot are declared AI-made.

## Build / test / deploy
See README.md (Rebuild, Test, Build and deploy). Always: autotest → look at screenshots → export all three → scp web + APK → `curl -sI https://maxims.top/seabattle/index.pck`.

## Conventions
decisions.md lists units, axes, node prefixes (TURRET_/GUN_/MUZZLE_/SEARCHLIGHT_/FUNNEL_/LIGHT_), grid coordinates and the network protocol.
