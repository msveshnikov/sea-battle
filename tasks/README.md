# Sea Battle — task files (game-pipeline)

Run 1 (this vertical slice = the whole game, one arena) was done in a single session on 2026-11-22.
Each task below is written so a fresh autonomous Claude Code session can redo or extend it
("do tasks/task2.md"). Block A (autonomous mode) and Block B (free assets only, everything procedural)
from the pipeline skill apply to all of them. Read decisions.md first and obey its conventions.

| Task | Goal | Scripts | Output |
|---|---|---|---|
| task1 | Environment & props | make_textures.py, build_env.py (islands, rocks, palms, lighthouse, pier, buoys, markers) | assets/env, renders/env |
| task2 | Vehicles | build_ships.py (battleship, cruiser, destroyer, patrol boat, plane, torpedo, shell) with TURRET_/GUN_/MUZZLE_ pivots | assets/ships, renders/ships |
| task3 | Arena layout | build_env.py `layout()` → grids, island circles, buoys, cameras, moods | assets/levels/arena_layout.json |
| task4 | Effects | scripts/fx.gd (explosion, splash, muzzle, fire, trails, rings, sonar), ship sinking, night lights | — |
| task5 | Game | main/board/ai/net/hud…, autotest, exports, deploy | builds on maxims.top/seabattle |

## Ideas for run 2
- More arenas (arctic fjord, volcanic night, harbour) = new `build_<arena>.py` + `<arena>_layout.json` + a picker.
- Ship skins per fleet (player can choose colours), a campaign of AI admirals with portraits.
- Ranked online with a tiny lobby list instead of blind quick match; reconnect after a dropped socket.
- Replace synthesized music with a composed track; voice barks ("Hit!", "Torpedo in the water!").
