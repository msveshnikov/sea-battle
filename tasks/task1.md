# Task 1: Archipelago environment and props (Blender)

Block A + Block B apply. Style: `concept/scenes/battle_day.png` — rocky tropical islets with tan boulders,
palms, white sand, turquoise shallows, a white lighthouse with red bands and a keeper's house with an orange roof.

1. `blender/scripts/make_textures.py` (system Python, numpy): hull, deck, steel, windows (+emit), sand, grass, rock,
   bark, palm leaf (alpha), plaster, roof tiles, wood, flag.
2. `blender/scripts/build_env.py`: irregular islands (beach shelf, cliffs, grassy top, underwater skirt), boulders,
   palms (curved trunk, drooping alpha fronds, coconuts), lighthouse (`LIGHT_beacon`), pier, corner buoy (`LIGHT_buoy`),
   miss marker buoy, hit flare float.
3. Export glTF to assets/env; render previews to renders/env and compare with the key art.
