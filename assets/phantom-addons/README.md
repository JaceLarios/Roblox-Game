# Phantom addons — Claude (2026-10-08)

The 15 ghost addons sold for bolts at the Phantom Garage (FusionRecipes.PhantomAddons), modelled in Blender from the concept sheet https://claude.ai/artifact/6pWuFngQZNMWdvbTRiz7TA.

| Shelf (size) | Addons |
|---|---|
| Wisp (4.6 studs) | Will-o'-Wisp Lanterns, Phantom Exhaust, Crystal Ball Ornament, Graveyard Grille, Ecto Tank |
| Wraith (4.8) | Banshee Horn, Poltergeist Spoiler, Coffin Carrier, Witch's Cauldron, Specter Sails |
| Reaper (5.0) | Wraith Wheels, Soul Turbo, Hearse Canopy, Reaper Scythes, Ghost Chauffeur |

The longest side is a little bigger than the Legendary addons (4.5), since they're the top shelf. All 15 are under 12,000 triangles, in 4 to 9 parts (one per material).

## Files

- `build_phantoms.py`: the whole builder. `E:/blender.exe --background --factory-startup --python build_phantoms.py` rebuilds every model, exports one JSON per addon plus `manifest.json` (same format as `assets/new-addons`: per-material parts, Blender Z-up turned into Roblox Y-up, front along +Z), saves `Phantom-Addons.blend` and renders a preview PNG per addon. Add `-- --norender` to skip the renders. It never touches an open Blender window.
- `phantom-addons-sheet.jpg`: all 15 previews on one sheet.
- `import.edit.luau`: Studio Edit mode. Serve this folder on `http://127.0.0.1:8766/` first. Uploads each part as a Mesh asset and builds the models in `ServerStorage.PhantomAddons_Staging_<time>`. Poll `_G.PhantomAddonImport`.
- `install.edit.luau`: moves the staged models into `ReplicatedStorage.ItemModels` (backing up any same-named model) and checks that each builds as a viewport copy and a world copy. Rolls back on any failure.

## The look

The ghost palette: ectoplasm mint, wisp blue and violet glow, over black iron, bone, gold and dark violet enamel. In Roblox: glow parts are Neon, "mist" parts are Neon at 50% transparency, ghost sheets and lace are see-through plastic, the crystal ball and lantern panes are Glass, the coffin and mast are Wood, and the tombstone is Slate. Iron, chrome, gold, enamel and rubber use the same `AddonDetail_*_v2` material variants as the other addons.

The game's ghostly stand-in (`ItemVisuals.Ghostly`) is only used while an addon has no model of its own, so it no longer applies to these 15. The 105 Spectral builds made with them still use stand-ins until their own models exist (docs/PHANTOM_MODELS.md).
