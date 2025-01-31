return {
	evalDownstream	= function(x) return "11.45.14"; end,
	cachePath	= "/tmp/rollmeow-test.cache.lua",
	packages	= {
		["invalid-follower"] = {
			url	= "https://example.com",
			follow	= "invalid",
		};
	},
};
