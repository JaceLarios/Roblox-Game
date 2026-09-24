# Race Wars art

- `checker.png` — the white/grey checker tinted onto every wall and floor (`rbxassetid://126970654411709`).
- `travel_card.png` — the Travel menu's Race Wars picture, drawn by `draw_card.py` (`rbxassetid://136532362963777`).

## Props (`ServerStorage.RaceProps`)

The trees and rocks on the track are AI-generated meshes, one tree and one rock-type prop per level theme, stored as MeshParts named `<theme>_tree` / `<theme>_rock` in `ServerStorage.RaceProps`. They exist only in the place file, not in this repo. `RaceTrack.luau` scales them, turns them to random angles and places them. A theme with no props there falls back to its part-built obstacles.

Rocks are solid (Hull collision). Trees are not; `RaceTrack` gives each one an invisible trunk post instead, so cars brush under the branches.

To rebuild one, make a MeshPart with these ids, name it as below and put it in the folder:

| Prop | What | MeshId | TextureID |
| --- | --- | --- | --- |
| grass_tree | Round leafy oak | rbxassetid://101583251115712 | rbxassetid://91388591697216 |
| grass_rock | Mossy grey boulder | rbxassetid://103593400611761 | rbxassetid://91417347685352 |
| desert_tree | Saguaro cactus | rbxassetid://127819927370426 | rbxassetid://96733346910775 |
| desert_rock | Layered sandstone boulder | rbxassetid://77481761996416 | rbxassetid://72849107982794 |
| snow_tree | Snowy pine | rbxassetid://101375277444082 | rbxassetid://111307685394106 |
| snow_rock | Snow-capped boulder with ice crystals | rbxassetid://131494829917902 | rbxassetid://89351583933253 |
| volcano_tree | Charred dead tree with embers | rbxassetid://100738571858455 | rbxassetid://76853377530406 |
| volcano_rock | Basalt boulder with lava cracks | rbxassetid://107339830855193 | rbxassetid://128073328936369 |
| neon_tree | Neon palm | rbxassetid://130270178896872 | rbxassetid://132723207305686 |
| neon_rock | Neon crystal cluster | rbxassetid://74784629868673 | rbxassetid://133041700815274 |
