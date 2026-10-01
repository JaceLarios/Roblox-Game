# Credits: 3D models used in Junkyard Fusion

Some cars are built from free Creative Commons models. Their licence
(**CC BY 4.0**: <https://creativecommons.org/licenses/by/4.0/>) lets us use
them in a game that makes money and change them, on one condition: we
credit the creator, link the original, name the licence, and **say that we
changed it**.

The list of every model and where it came from is the user's Google Doc,
"Roblox Models page":
<https://docs.google.com/document/d/11qrkoSve66ZyDTXzAfZ7g3aJp8jnf6QlqscydShYf2g/edit>
(the in-game name above each link). Both entries below were checked
against it and against Sketchfab on 2026-09-30.

Where the credits go:

- **The game's description on Roblox.** Paste the block below and keep it
  up to date as cars are added.
- **In game.** The "Model Credits" button (bottom right; Codex's
  `StarterGui.VehicleModelCredits`, also `VehicleModelCredits.client.luau`
  and `assets/vehicle-credits/install.edit.luau`) lists every model in
  full. Each Secret car also has a `credit` line in
  `FusionRecipes.SecretCars` (src/ReplicatedStorage/FusionRecipes.luau),
  shown on its Index card. Add a car's short
  credit there when it goes into the game.

Every car is renamed, and badges and brand lettering are removed, because
real car brands are trademarks (see HANDOFF.md).

---

## Ready to paste into the game description

```
3D model credits (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/):
• Toro SVO: based on "Lamborghini Aventador SVJ SDC ( FREE )" by SDC PERFORMANCE (sketchfab.com/Lambo_SC04). Modified by RaceWerks.
• Toro: based on "Lamborghini Temerario (2025)" by Harsh Palan (sketchfab.com/harshpalan). Modified by RaceWerks.
Car names and badges changed. Not affiliated with or endorsed by any car maker.
```

---

## The models

### 1. Toro SVO (in the game now)

| | |
|---|---|
| In-game name | Toro SVO (Secret car) |
| Studio model | `ReplicatedStorage.ItemModels.SVO` |
| Original title | Lamborghini Aventador SVJ SDC ( FREE ) |
| Creator | SDC PERFORMANCE™️ (@Lambo_SC04), <https://sketchfab.com/Lambo_SC04> |
| Original | <https://sketchfab.com/3d-models/lamborghini-aventador-svj-sdc-free-784e4656aca649cca55d6b18740a19b2> |
| Licence | CC BY 4.0 (commercial use allowed) |
| What we changed | Tiffany-blue paint; carbon hood, roof scoop and skirts; "SVO" decals; chrome rims; red calipers; front badge removed; rear brand lettering covered; lower-detail export; renamed. (Still to come: resized, wheels rigged to roll.) |

Short credit (in game): `Model by SDC PERFORMANCE (Sketchfab), CC BY 4.0, modified`

Full credit:

> "Lamborghini Aventador SVJ SDC ( FREE )" by SDC PERFORMANCE
> (https://sketchfab.com/Lambo_SC04), licensed under CC BY 4.0
> (https://creativecommons.org/licenses/by/4.0/). Modified by RaceWerks for
> Junkyard Fusion: repainted, new decals and wheels, badges and brand
> lettering removed, detail reduced and renamed.

### 2. Toro (from the Temerario model; in the game since 2026-09-30)

| | |
|---|---|
| In-game name | Toro (Secret car) |
| Studio model | `ReplicatedStorage.ItemModels.Toro` (Codex, VisualRevision Replacement-Carbon-v13) |
| Original title | Lamborghini Temerario (2025) |
| Creator | Harsh Palan (@harshpalan), <https://sketchfab.com/harshpalan> |
| Original | <https://sketchfab.com/3d-models/lamborghini-temerario-2025-83bcf28aade742a3b726c28812fd9672> |
| Licence | CC BY 4.0 (commercial use allowed) |
| What we changed | Metallic lime paint, chrome rims, widebody arches with carbon lips, carbon skirts, splitter, wing and diffuser, front fender louvres, badge and logo meshes removed, lower-detail export resized for Roblox, renamed. (Codex's record: assets/toro-replacement/source-record.json) |

Short credit (in game): `Model by Harsh Palan (Sketchfab), CC BY 4.0, modified`

Full credit:

> "Lamborghini Temerario (2025)" by Harsh Palan
> (https://sketchfab.com/harshpalan), licensed under CC BY 4.0
> (https://creativecommons.org/licenses/by/4.0/). Modified by RaceWerks for
> Junkyard Fusion: lime paint, widebody kit, carbon accents, custom wheels,
> wing and diffuser; badges and branding removed; detail reduced, resized and
> renamed.

Notes:

- About 479,000 triangles, twice the SVO before its reduction and around
  seven times a normal car. It needs a much lighter version for Roblox.
- **Build it from this model.** Codex's first Toro (Toro-v3.blend) was
  made from a different Temerario: Ddiaz Design's, licensed CC BY-NC-SA
  (no commercial use, and taken from the game CSR2). That one cannot go in
  this game. The credit here is only right if the Toro is built from Harsh
  Palan's model above.
- Its Sketchfab description says "(From Lamborghini's Website)". A CC
  licence only counts if the uploader had the right to give it, so there is
  some risk this one was not theirs to share. Removing the badges and
  lettering and changing it well away from the original lowers that risk.

---

## Adding the next model

For each new model, copy the section above and fill in: in-game name,
Studio model name, original title, creator (name, @username, profile link),
the model's link, licence, and what was changed. Check the licence on the
model's Sketchfab page first: **CC BY** and **CC0** are fine for this game;
anything marked **NonCommercial (NC)** is not (the game sells gamepasses),
and **NoDerivatives (ND)** means it cannot be changed at all.
