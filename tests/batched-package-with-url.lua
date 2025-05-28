-- Batched packages may have field url set.

return {
	evalDownstream	= function(x) return "11.45.14"; end,
	cachePath	= "/tmp/rollmeow-test.cache.lua",
	packages	= {
		["example"] = {
			url = "https://example.com",
			regex = ".",
			postMatch = function() return "1.2.3"; end,
		};

		["batched-package-with-url"] = {
			url = "https://example.com",
			follow = "example",
		};
	},
};
