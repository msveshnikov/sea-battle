# Task 5: The game in Godot

## Mode / assets
Block A + Block B of the game-pipeline skill. Godot 4.7, GDScript, UI built in code (UiKit).

## Goal
Sea Battle with Russian rules on the arena from task 3: placement, turns, AI admirals (3 levels), Arcade abilities
(radar, torpedo, airstrike), cinematic camera (attack/defence presets), effects from task 4, sound, EN/RU,
online duels through the room relay, Windows/Web/Android builds deployed to maxims.top/seabattle.

## Steps
1. Board rules (`board.gd`), AI (`ai.gd`), world (`arena.gd`, `grid_view.gd`, `ship_view.gd`, `fx.gd`).
2. Flow (`main.gd`): one action → outcome → animation path for both opponents; the defender resolves.
3. UI (`hud.gd`): title over the painted concept art, setup, online lobby, settings, placement bar, HUD, pause, game over.
4. Online (`net.gd`): quick match pairing, private 4-letter rooms, ready/shot/res/fleet/rematch/surrender.
5. `--autotest` (AI vs bot, screenshots) for every mood and both renderers; `--autotest --online` twice for a network match.
6. Export all presets, upload web + APK, open the live page and play a turn.

## Done when
Autotest passes in all moods on Mobile and Compatibility renderers, the online bot match finishes, builds are live.
