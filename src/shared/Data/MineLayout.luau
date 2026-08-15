-- The mine layout, one character per grid cell.
-- Row index maps to +Z, column index maps to +X.
--
--   .  solid rock (nothing built)
--   #  tunnel
--   N  tunnel + rich cell (wide chamber, extra ore nodes)
--   D  tunnel + elevator DOWN to the next tier
--   U  tunnel + elevator UP to the previous tier (tier 1's U goes to surface)
--
-- Pairing rule: tier N's D connects to tier N+1's U.
-- The surface hub is tier 0 and owns the player spawn.
-- Each tier may have at most one D and one U.
-- Every row within a tier must be the same length.

local MineLayout = {
	{
		Tier = 1,
		Rows = {
			"....U....",
			"....#....",
			"..###N...",
			"..#...#..",
			".N#...###",
			"..#.....N",
			"..#####..",
			"......#..",
			"......D..",
		},
	},
	{
		Tier = 2,
		Rows = {
			"......U..",
			"......#..",
			"..N####..",
			"..#...#..",
			"###...N..",
			"#.#####..",
			"#.....#..",
			"#..N..#..",
			"#######..",
			"D........",
		},
	},
	{
		Tier = 3,
		Rows = {
			"U........",
			"#........",
			"####N....",
			"...#.....",
			"..N#..N..",
			"...####..",
			"......#..",
			"..N...#..",
			"..#####..",
		},
	},
}

return MineLayout
