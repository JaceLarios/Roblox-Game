# Central all-time leaderboards

Two separate boards at (29, 1.2, -9) and (29, 1.2, 9), near the central crane and outside its 20-stud sweep/drop circle. Both sides of each board show the same category so players can approach from either direction.

- All-Time Money: cumulative coins earned, not current wallet balance.
- All-Time Playtime: existing accumulated minutes, formatted as hours and minutes.
- Each row includes rank, username, full-body Roblox avatar thumbnail and total.
- Scrollable global Top 100, existing 60-second ranking cache and 15-second display check. Unchanged rows are not rebuilt every check.

Existing DataStore names, earning/time recording, autosave and join/leave logic are unchanged. Ranking records now include their userId for thumbnails. No player totals were reset or backfilled.

Verified in Studio Play: two boards, two faces each, old board absent, crane clearance, both real saved players shown on both boards, and all four front-facing avatar images loaded. Actual money values differ from wallet balance as expected; time rendered as 10h 39m and 0h 40m during inspection. Output showed no errors. Full 100-row touch scrolling remains untested because only two players are currently ranked.

New renderer: ServerStorage.CentralLeaderboards; invoked by PlotManager. Backup: ServerStorage.BeforeTwoLeaderboards_1790188401. Playtest was left running with the normal camera restored. Not published to Roblox.
