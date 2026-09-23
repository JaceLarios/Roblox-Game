# Legendary jet fusion models

Built from main `87ff281b032c158ba462a1c62a170749d08ed37c` and installed in the open Studio Edit place. This is a procedural source backup, not a Roblox publication or a complete place export.

| Exact template name | Detailed base | Parts | Longest side |
| --- | --- | --- | --- |
| Rocket Rider | Dirt Bike | 161 | 7 studs |
| Afterburner GT | Muscle Car | 343 | 7 studs |
| Sky Marshal | Cop Cruiser | 330 | 7 studs |

`preview.png` is an actual Studio client viewport capture. Each model preserves the detailed base vehicle and adds segmented turbines, intake fans, mounting braces, metal bands, fasteners, heat cores, fuel lines, and wear marks. The cars have paired jets and rear wings; the bike has a single side-mounted turbine.

## Restore into Studio

1. Stop Play. The detailed Dirt Bike, Muscle Car, and Cop Cruiser must already exist in `ReplicatedStorage.ItemModels`. Their source backups are in `../detailed-vehicles/` in this same commit. Use those versions to reproduce this build exactly; the builder clones the current base templates.
2. Run `build.luau` in the Edit command bar/MCP. It creates the three results in `ServerStorage.LegendaryBuildStaging_20260923`. It refuses to replace an existing result.
3. Inspect the staged models, then run `install.luau`. It validates all three before moving them into `ReplicatedStorage.ItemModels`, again refusing to overwrite existing templates.
4. Save the place. Publishing is a separate step. Rojo's script sync alone does not run these builders or install models.

Do not delete an existing result just to rerun this builder. Preserve it in a separate backup first if an intentional replacement is needed. A failed build may leave a staging folder; inspect/remove that specific staging folder before retrying.

## Verified in fresh Studio Play

- All three exact Jet Engine recipes resolve to their corresponding model.
- Template bounding boxes have a 7-stud longest side.
- ItemVisuals.Create works at scales .55, .75, 1, and 1.3, producing welded assemblies rather than placeholders.
- Ground alignment, translation/rotation, resizing, weld positions, mutation tint, and fade transparency passed helper checks.
- ItemVisuals.CloneForViewport and the existing GarageTheme podium render all three models. All 15 MeshPart assets preloaded successfully.
- Play-test Output contained no errors. An initial Edit-mode helper attempt used a stale cached module; the checks above were repeated successfully in fresh Play.

No recipe, economy, save, UI, world-generation, or base-template scripts were changed. Test clones did not grant or remove inventory items. Temporary runtime checks were destroyed; Studio was returned to Edit. An Edit-only review display remains at `Workspace.CodexLegendaryJetReview` around (70, 505, 0).

Still untested: an actual player fusion and saved-pad round trip, published-server behavior, and mobile/many-model performance. The other fused-result rebuild/rescale tasks remain outstanding.
