# Index item details — 2026-09-23

Clicking a discovered Index item now opens a model/value/details panel rather than immediately equipping a companion.
- Shows base value and potential pad income from the current inventory snapshot.
- Shows catalog base value for discovered items without an inventory copy; sell/place remain disabled.
- Choose among owned copies (including mutations) with previous/next buttons.
- Place on Pad and Sell call the existing inventory-index remotes. Full pads disable placement.
- Equip Companion remains available as an explicit separate button.
- Refreshes from inventory/placement updates, re-resolves indices before dispatch, and temporarily locks actions while updating.

Changed: ReplicatedStorage/IndexGallery and StarterPlayerScripts/GameUI only.
Original Studio scripts cloned to ServerStorage.BeforeIndexDetails_20260923.

Verified in Studio: compilation, actual Index click/details, real owned value/income and full-pad state; isolated UI callbacks received slot 17 for placement and shifted slot 23 for sale; empty inventory disables both; opening details does not equip. Output had no script errors.
No real items sold/placed, no data reset. Existing server endpoints were not changed or re-tested end-to-end with live transactions.
Returned to Edit mode. Not published to Roblox.
