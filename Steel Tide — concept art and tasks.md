# Steel Tide (Морской бой: Стальной прилив) — concept art and tasks

## 1. Pitch
A 3D remake of the classic 10×10 Sea Battle. Two fleets anchor in a tropical archipelago; each
side's waters are a glowing grid floating on a real animated ocean. You aim at enemy waters, your
flagship's turrets swing round and fire, the shell arcs across the sky with a smoke trail and
lands either as a white water column (miss, a marker buoy stays) or a fireball (hit, the hidden
ship catches fire). A sunk enemy ship breaks the surface, burns and goes under. When the enemy
fires, the camera swings to your fleet and you watch shells fall around your ships.

- Genre: turn-based naval strategy, short sessions (5–10 min).
- Camera: cinematic three-quarter view from above, orbit/zoom by drag/wheel/pinch, auto-cuts to the
  attacker → shell flight → impact.
- Fleet (Russian rules): 1× battleship (4), 2× cruiser (3), 3× destroyer (2), 4× patrol boat (1).
  Ships may not touch, not even diagonally. A hit gives another shot. Cells around a sunk ship
  are marked automatically.
- Modes: **Classic** and **Arcade** (each side gets one Radar scan 3×3, one Torpedo that runs along
  a row until it hits, one Airstrike — a plus-shaped 5-cell bombardment).
- Opponents: AI admirals Easy / Normal (hunt & target) / Hard (probability heat map);
  **online multiplayer** — Quick match or a private room code (WebSocket relay).
- Cycle: time of day per match — Day, Sunset, Night (night = searchlights, flares, glowing grid).
- Platforms: Windows, Web, Android.

## 2. Style block
```
Game concept art in the style of premium stylized mobile strategy games and naval dioramas:
chunky slightly toy-like proportions, crisp hand-painted PBR materials, bold readable silhouettes,
no photorealism, no cartoon faces. Tropical archipelago, 1940s-inspired steel warships.
Consistent palette: deep teal ocean, turquoise shallows, battleship grey hulls with red
anti-fouling below the waterline, warm teak decks, signal orange accents, glowing cyan
holographic grid lines. Strong warm sun, soft long shadows, sparkling water,
three-quarter view from above, 16:9.
```

## 3. Mood add-ons
- Day: `Bright midday, clear sky with soft cumulus, sparkling turquoise water.`
- Sunset: `Golden hour, low orange sun, long shadows, pink-violet sky, warm reflections.`
- Night: `Moonlit night, deep navy water, ship searchlights and orange fire glow, cyan grid glowing strongly.`

## 4. Prompts
### Scenes
- **Key art / battle** (`concept/scenes/battle_day.png`): `Two opposing fleets anchored in a tropical
  lagoon, a glowing cyan 10×10 grid floating on the water in front of each fleet, a battleship firing
  a broadside, shell arcs with smoke trails, a white water splash and an orange fireball on a burning
  enemy cruiser, rocky islands with palms and a white lighthouse framing the scene. no text`
- **Sunset & night variants** of the same scene with the mood add-ons.
### Ships (`concept/ships/fleet_sheet.png`)
`Ship design sheet of four stylized 1940s warships side view and three-quarter view on a neutral
grey background: battleship with three twin turrets and a tall bridge tower, cruiser with two
turrets and two funnels, destroyer with one turret and torpedo tubes, small patrol torpedo boat.
Battleship grey hulls, red below the waterline, teak decks, orange accents, number decals. no text`
### UI (`concept/ui/title_screen.png`)
`Game title screen, the fleet at sunset under a dramatic sky, empty space in the upper middle for a
logo and a column of menu buttons, brushed steel and brass UI frames with cyan glow. no text`

## 5. Tasks (vertical slice = the whole game; one arena)
- task1 — environment: ocean shader, islands, rocks, palms, lighthouse, buoys, grid frame, markers.
- task2 — vehicles: 4 ship classes with separate TURRET_/GUN_ pivots, wreck variants, aircraft for airstrike, torpedo.
- task3 — arena layout: two grids, fleet anchoring sides, camera rigs, lighting presets per mood → `assets/levels/arena_layout.json`.
- task4 — effects: muzzle flash, shell trail, splash, explosion, fire/smoke, sinking, flares (Godot particles).
- task5 — the game: placement, rules, AI, abilities, camera direction, UI, sound, multiplayer, autotest, builds.

The task texts live in `tasks/` (Block A autonomous mode + Block B free assets apply to all).
