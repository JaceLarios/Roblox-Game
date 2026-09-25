-- Replace each 0 with the pass Asset ID from this experience's Creator Hub.
-- Zero means unavailable: no ownership request and no purchase prompt.
--
-- icon: the big badge shown on the pass's banner card.
-- bgIcons: emoji that drift/spin lazily in the banner's background — see
-- ShopUI.client.luau's addFloatingIcons, a small reusable helper built
-- specifically so a brand new gamepass gets the same "alive" banner for
-- free just by listing icons here, no new animation code needed.
return {
	DoubleCoins = {
		id = 0, name = "2x Coins", icon = "💰",
		description = "Double coins from sales, objectives, daily rewards and playtime. Stacks with sell boosts.",
		bgIcons = { "💰", "✨", "💰", "✨" },
	},
	ExtraStorage = {
		id = 0, name = "+50 Inventory Space", icon = "📦",
		description = "Fifty more inventory spaces on top of your Storage Space upgrades.",
		bgIcons = { "📦", "🎒", "📦" },
	},
	StarterPack = {
		id = 0, name = "Starter Pack", icon = "🎒",
		description = "A permanent coin and speed boost from day one.",
		bgIcons = { "🎒", "💨", "💰" },
	},
}
