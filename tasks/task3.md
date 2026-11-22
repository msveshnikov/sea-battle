# Task 3: Arena layout

Block A applies. Two 10×10 grids (cell 4 m) at Godot (0, ±28), islands around them (none inside a grid or the
channel between them), rocks near the corners, the lighthouse island on the enemy's left as in the key art.
`build_env.py layout()` writes `assets/levels/arena_layout.json`: grids, island circles (for water shallows/foam),
corner buoys, beacon, camera presets (title, placement, attack, defense, overview) and moods (day, sunset, night:
sun direction/colour/energy, sky top/horizon, ambient, water deep/shallow, fog, lights on/off).
Check: screenshots from every camera preset in every mood.
