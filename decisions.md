# Decisions (made without asking)

- **Title**: "Sea Battle / Морской бой" (renamed from "Sea Battle" on the user's request), subtitle "Fleet vs fleet / Флот против флота". Version 2.0.0 (remake of the 1.x Cordova app), same Android package `com.maxsoft.seabattle`.
- **Rules**: Russian classic fleet (1×4, 2×3, 3×2, 4×1), no touching, hit = extra shot, auto-mark around sunk ships and diagonals of hits (both sides see the dots).
- **Arcade**: 1 radar (count of ship cells in 3×3, zero → area marked empty), 1 torpedo (row, from column A, misses along the path are revealed), 1 airstrike (plus of 5 cells). An ability ends the turn unless it hit.
- **Units/axes**: 1 unit = 1 m, Blender Z up / bow −Y → Godot Y up / bow +Z. Cell = 4 m. Grids: player centre (0, 28), enemy (0, −28) in Godot X/Z. Cell (x, y) → x along +X, y along +Z (row 1 is the far row from the player's camera).
- **Node prefixes**: `TURRET_k` (yaw, rest yaw baked), `GUN_k` (pitch about local X, negative = up), `MUZZLE_k`, `SEARCHLIGHT_n`, `FUNNEL_n`, `PROP`, `LIGHT_beacon`, `LIGHT_buoy`.
- **Ship scale**: models are 15.2/11.3/7.5/3.5 m long, shown at ×1.18 for a chunky readable look (overhang into the mandatory empty neighbour cells is fine).
- **Enemy fleet**: same models, recoloured in code (dark blue-grey, crimson accents). Hidden until sunk; hits on hidden ships show a flare buoy + fire on the water.
- **Enemy guns** fire from beyond their grid so the muzzle flash never gives positions away.
- **Water**: vertex waves + normal maps + analytic shallows/foam from island circles in the layout JSON (no depth texture → works on Compatibility).
- **Renderers**: Mobile on desktop, Compatibility on web/Android. Grid/foam shaders use `fog_disabled` (fog on additive meshes washed the grid out).
- **Sound/music**: synthesized with numpy (no downloads). Fonts: Russo One + Rubik (OFL, Google Fonts, Cyrillic).
- **Multiplayer**: reuse the existing room relay (no new server). Quick match: the two lowest ids in `quick-<mode>` pair, the lower creates `room-q<id><rand>`. Private rooms: 4 letters. The defender resolves each shot on its own board and replies with the outcome, so no fleet data is ever sent before the game ends. First turn: lower relay id. Disconnect / surrender = win for the other side.
- **Protocol** (JSON over the relay): `hello{name,creator,mode?,mood?}`, `pair{a,b,room,mood}`, `ready`, `shot{a:{kind,cell}}`, `res{o:outcome}`, `fleet{ships}` (winner reveals), `surrender`, `rematch`, `bye`.
- **Camera (playtest 2026-11-22)**: after a hit the turn continues with the camera untouched (the player may have zoomed/rotated); presets switch only when the turn passes. Attack view is higher and closer (far cells bigger for fingers).
- **Night (playtest)**: brighter moon and ambient; waves are damped to 12% inside both grids so they no longer wash over the hulls as dark blue patches.
