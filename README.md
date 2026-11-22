# Sea Battle — Морской бой 3D

A 3D remake of the old Cordova "Sea Battle" (kept in `legacy/`). Two fleets anchor in a tropical
archipelago, each side's waters are a glowing holographic 10×10 grid on an animated ocean.
Turrets swing round and fire, shells arc across the sky, misses throw up water columns and leave
marker buoys, hits set hidden ships on fire, sunk ships surface burning and go under.

- **Rules**: Russian classic — 1×4, 2×3, 3×2, 4×1, ships may not touch, a hit gives another shot,
  cells around a sunk ship and the diagonals of a hit are marked automatically.
- **Arcade** rules add one Radar (3×3 contact count), one Torpedo (runs along a row until it hits)
  and one Airstrike (plus-shaped bombardment) per side.
- **Opponents**: AI admirals Cadet / Captain / Grand Admiral (random+follow-up, hunt/target,
  probability heat map), or **online**: quick match or a 4-letter private room code.
- **Time of day**: day, sunset, night (searchlights, lit windows, lighthouse beam, buoy lamps).
- English / Russian UI. Windows, Web, Android.

Play: https://maxims.top/seabattle/ · APK: https://maxims.top/seabattle/SeaBattle.apk

## How it is made (game-pipeline)

Nothing is made by hand; every file can be rebuilt by a script.

| Stage | Tool | Output |
|---|---|---|
| Concept art | ChatGPT (built-in browser) | `concept/` key art, fleet sheet, title screen |
| Textures | `blender/scripts/make_textures.py` (numpy) | `assets/textures/*.png` |
| Ships, plane, torpedo, shell | `blender/scripts/build_ships.py` (Blender) | `assets/ships/*.gltf`, `renders/ships/` |
| Archipelago + props + layout | `blender/scripts/build_env.py` (Blender) | `assets/env/*.gltf`, `assets/levels/arena_layout.json`, `renders/env/` |
| Sound + music | `scripts/tools/make_audio.py` (numpy synth) | `assets/audio/*.wav` |
| Game | Godot 4.7, GDScript, UI built in code | `scenes/main.tscn`, `scripts/` |

### Rebuild
```
python blender/scripts/make_textures.py
blender -b --factory-startup -P blender/scripts/build_ships.py      # [-- --only cruiser --no-render]
blender -b --factory-startup -P blender/scripts/build_env.py        # [-- --no-render]
python scripts/tools/make_audio.py
godot --headless --path . --import
```
Tools on this PC: Blender `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`,
Godot `C:\Users\msves\OneDrive\Рабочий стол\Godot_v4.7.2-stable_win64.exe`.

### Test
```
godot --path . -- --autotest --mood=day|sunset|night [--classic] [--shots-only]
godot --path . -- --autotest --online --qroom=<anything>      # run twice: two bots play online
```
Screenshots and `autotest.log` go to `renders/game/`.

### Build and deploy
```
godot --headless --path . --export-release "Windows Desktop" build/windows/SeaBattle.exe
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-debug "Android" build/android/SeaBattle.apk
scp build/web/* build/android/SeaBattle.apk ubuntu@severance.lol:/var/www/maxims/seabattle/
```

## Code map
- `scripts/main.gd` flow: title → setup/lobby → placement → battle → game over; one action→outcome→animation path for AI and online.
- `scripts/board.gd` rules, `scripts/ai.gd` admirals, `scripts/net.gd` WebSocket relay client.
- `scripts/arena.gd` builds the world from the layout JSON, moods, projectiles; `grid_view.gd` holographic grids + markers; `ship_view.gd` ships (aim, fire, burn, sink); `fx.gd` particles; `camera_rig.gd` cinematic camera.
- `scripts/hud.gd`, `ui_kit.gd`, `fleet_panel.gd` UI; `game.gd` settings/strings; `sfx.gd` sound.
- Shaders: `shaders/water|sky|grid|foam.gdshader` (all Compatibility-safe).
- Multiplayer uses the existing room relay `wss://severance.lol/village-ws` (source: `C:\My-progs\Godot\village\server\relay.js`), rooms prefixed `seabattle-`.
