# Illustrated UI refresh

The user approved the large outlined UI and then requested a more distinctive junkyard color palette. This commit contains the final cream/copper/teal/steel/mint design, not the rejected monochrome prototype.

## Source
- GameUI.client.luau: larger inventory, working name search, selection details, outlined headings and updated upgrade visuals. Uses existing gameplay callbacks.
- ShopUI.client.luau: responsive offer grid, Gamepasses/Pets/Boosts headings and code redemption at the bottom.
- NavButton.luau: illustrated navigation without heavy rectangular tiles.
- UIStyle.luau: shared palette, typography, panel sizing, modal visibility and atlas sprites.

## Assets
assets/ui/ui-icons.png is the original transparent nine-icon atlas. Its Roblox image is rbxassetid://82552057143764. The original PNG is 1254 square; Roblox serves it at 1024 square, so sprite rectangles use 341px cells with rounded third-width offsets. Keep the original for future artwork changes. The generation prompt is stored alongside it.

## Gameplay status
Only presentation scripts were changed. GitHub's existing server scripts, SecretPets config, fusion effects, save behavior and receipt handling are preserved. The shop's Pets section is Coming Soon and does not yet expose the new egg mechanics. Existing gamepasses are disabled until real IDs are configured.

## Validation
Studio Play startup and Output checks passed without game-script errors. Checked desktop Shop/Inventory, portrait Shop, inventory search results and selection, section order, disabled pass controls and the Rewards link. Visually checked the final color-only adjustment. Original avatar and item models remain intact.

No transactions were triggered for testing; no data was reset. Published Roblox client, multiplayer, real purchases and broader phone/gamepad coverage remain untested. The game changes have not been published to Roblox.
