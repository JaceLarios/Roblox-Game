# Claude review fixes — 2026-10-01

Pulled main at 8af1784. Original templates are preserved in `ServerStorage.BeforeClaudeReviewFixes_1790909897`.

`repair_fusions.py` applies targeted changes to the approved historical exports without overwriting them. The 17 current exports are in `import/`; they supersede the corresponding older exports. Sign triangles are separated from body paint. Nitro/exhaust/rocket equipment is lowered clear of lettering, and Legendary truck cables run above the sign. Three hover fan housings use contrasting dark cast metal while keeping the cyan blades/rings.

`install-fusions.edit.luau` preserves the live bounding size and copies the original wheel parts and their exact metadata. It checks recipes, viewport cloning, resizing, wheel motion and hover controllers, with rollback on failure. Live golf carts are untouched.

The Toro optimization uses mesh geometry captured directly from the current Studio template, including UVs. `toro-live/` is the original geometry and `toro-optimized/` is the 80,219-triangle result. Existing appearance, transforms and wheel metadata are retained by cloning the live parts and replacing geometry only. The Blender file contains the local mesh components; the saved Studio snapshot supplies their assembly transforms and materials.

## Source-rights note

The saved source record identifies Harsh Palan's Sketchfab listing as CC BY 4.0, but its description says the model came “From Lamborghini’s Website.” What remains unverified is whether that original website model was licensed for redistribution and whether the uploader had authority to offer it under CC BY; the existing credit has not been changed. This session could not re-open the listing (403), so this explanation describes the recorded evidence, not newly verified permission.

## Optional cleanup review — nothing deleted

- `WarpModelsStaging_1790862278` and `BeforeWarpBatch_1790862874`: empty, no script references found; removal candidates.
- `SVO_Optimized_Staging`: not an exact duplicate: two part/material differences remain versus live SVO; retain.
- `RemainingModelsStaging_1790875486`: historical 52-model staging set, now partly superseded; keep until the new recovery backup is saved and approved.
- `BeforeSVOOptimization_1790875575`: unique old high-detail SVO rollback; retain unless the user explicitly chooses to discard this history.
- All other backup folders: retained; no blanket deletion is authorized.
