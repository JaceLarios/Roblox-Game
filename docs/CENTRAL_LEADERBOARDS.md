# Central all-time leaderboards

## Opposite-side redesign
Supersedes the positions/style below. Money now stands at X=32, playtime at X=-32, both Z=0: 64 studs apart on opposite sides of the crane. Added steel housings, edge lighting, raised Global Top 100 headers, coin/clock badges, safety-striped supports, canopy, diamond-plate footing and highlighted top-three rows. Surface proportions match the display geometry.

LeaderboardBoards.client locally hosts the replicated RankingSurface GUIs in PlayerGui with Adornee set to the board, so scrolling accepts mouse/touch input. Server ranking updates remain replicated; no player save changes. GetSortedAsync(false,100) and a renderer limit of 100 enforce the global Top 100.

Verified native mouse-wheel scrolling on both categories using temporary client-only 100-row fixtures; scrolling advanced and rank 100 was reachable at the bottom. Fixtures were removed immediately; live data contains only two ranked players at present. Touch-device scrolling remains untested. Studio Output had no errors. Backup BeforeLeaderboardStyle_1790188636. Final small correction replaces an unsupported clock glyph with drawn hands/rim. Not published.

Two separate boards at (29, 1.2, -9) and (29, 1.2, 9), near the central crane and outside its 20-stud sweep/drop circle. Both sides of each board show the same category so players can approach from either direction.

- All-Time Money: cumulative coins earned, not current wallet balance.
- All-Time Playtime: existing accumulated minutes, formatted as hours and minutes.
- Each row includes rank, username, full-body Roblox avatar thumbnail and total.
- Scrollable global Top 100, existing 60-second ranking cache and 15-second display check. Unchanged rows are not rebuilt every check.

Existing DataStore names, earning/time recording, autosave and join/leave logic are unchanged. Ranking records now include their userId for thumbnails. No player totals were reset or backfilled.

Verified in Studio Play: two boards, two faces each, old board absent, crane clearance, both real saved players shown on both boards, and all four front-facing avatar images loaded. Actual money values differ from wallet balance as expected; time rendered as 10h 39m and 0h 40m during inspection. Output showed no errors. Full 100-row touch scrolling remains untested because only two players are currently ranked.

New renderer: ServerStorage.CentralLeaderboards; invoked by PlotManager. Backup: ServerStorage.BeforeTwoLeaderboards_1790188401. Playtest was left running with the normal camera restored. Not published to Roblox.
