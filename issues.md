# Issues and workarounds

- `project.godot` keys must be `rendering/renderer/rendering_method(.mobile/.web)`; plain `rendering_method` was ignored (ran Forward+).
- Fog is added onto `blend_add` meshes → the holographic grid turned milky on Compatibility. Fixed with `render_mode fog_disabled`.
- Right-anchored panels grew off-screen when their minimum size changed after anchoring → `UiKit.place` sets `grow_horizontal = BEGIN` for right/center presets.
- Sunset preset was over-saturated (orange sun + orange sky ambient + ACES) → softened sun/horizon colours.
- Shore foam from island circles sits slightly off the real coastline (islands are irregular); radius ×0.92 is a compromise.
