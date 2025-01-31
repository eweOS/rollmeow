return {
	evalDownstream	= function(x) return "11.45.14"; end,
	cachePath	= "/tmp/rollmeow-test.cache.lua",
	packages	= {
		["followed"] = {
			url	= "https://example.com",
			regex	= "THIS_SHOULD_NEVER_MATCH"
		},
		["follower"] = {
			url	= "https://example.com",
			follow	= "followed",
		};
	},
};
