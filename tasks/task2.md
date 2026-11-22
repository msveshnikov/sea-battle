# Task 2: Fleet models in Blender (vehicles)

## Mode / assets
Block A (fully autonomous, decisions.md / issues.md / report_task2.md) and Block B (everything procedural,
free assets only) of the game-pipeline skill apply.

## Goal
Warships for Steel Tide in the style of `concept/ships/fleet_sheet.png` and `concept/scenes/battle_day.png`:
chunky slightly toy-like 1940s warships, dark battleship grey, red anti-fouling with a black boot-top,
teak decks, orange funnel bands and accents.

## Inputs
concept/ships/fleet_sheet.png, concept/scenes/battle_day.png, decisions.md (axes, node prefixes).

## Steps
1. `blender/scripts/build_ships.py` builds: battleship (4 cells, 3 twin turrets A/B superfiring/C aft, stepped bridge,
   tripod masts, 2 funnels, secondary guns, AA, boats), cruiser (3 cells, 2 turrets, lattice mast, 2 funnels),
   destroyer (2 cells, 1 turret, torpedo tubes), patrol boat (1 cell), airstrike plane (PROP), torpedo, shell.
2. Hull = loft of stations (pointed bow, transom stern, sheer), UV U = 8 m along the hull, V = z (waterline at V 0.5).
3. Turrets: `TURRET_k` (yaw pivot), `GUN_k` (pitch pivot on the trunnion), `MUZZLE_k`; `SEARCHLIGHT_n`, `FUNNEL_n`.
4. Export glTF separate to assets/ships, textures shared in assets/textures; preview renders in renders/ships.
5. Compare the previews with the fleet sheet; iterate colours/proportions until they match.

## Done when
All 7 assets export, the game shows them with working turret aim, and the contact sheet matches the concept.
