# AGENTS.md — Sea Battle 3D (Морской бой)

## Where everything lives
- Project: `C:\My-progs\Godot\seabattle` (Godot 4.7 project in the root; old Cordova game in `legacy/`, git-ignored keystore there).
- Live web build: https://maxims.top/seabattle/ → server `ubuntu@severance.lol:/var/www/maxims/seabattle/`
- APK: https://maxims.top/seabattle/SeaBattle.apk (debug-signed, package `com.maxsoft.seabattle`, version 2.0.0 / code 20000).
- Multiplayer relay: `wss://severance.lol/village-ws` (shared with Gacha Village; source `C:\My-progs\Godot\village\server`). Rooms: `seabattle-quick-<mode>`, `seabattle-room-<CODE>`.
- Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`
- Godot 4.7.2: `C:\Users\msves\OneDrive\Рабочий стол\Godot_v4.7.2-stable_win64.exe`
- Concept art: `concept/` (ChatGPT chat "Generate Naval Game Art" holds the style reference).
- Save file: `user://settings.cfg` (Windows: `%APPDATA%\Godot\app_userdata\Sea Battle\`).

## Build / test / deploy
See README.md (Rebuild, Test, Build and deploy). Always: autotest → look at screenshots → export all three → scp web + APK → `curl -sI https://maxims.top/seabattle/index.pck`.

## Conventions
decisions.md lists units, axes, node prefixes (TURRET_/GUN_/MUZZLE_/SEARCHLIGHT_/FUNNEL_/LIGHT_), grid coordinates and the network protocol.
