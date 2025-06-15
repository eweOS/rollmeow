return {
	evalDownstream  = function(x) return "11.45.14"; end,
	cachePath       = "/tmp/rollmeow-test.cache.lua",
	packages        = {
		["mvim"] = {
			gitrepo	= "https://github.com/ziyao233/mvim.git",
			-- Matches nothing if there's a trailing newline
			regex   = "HEAD$",
		};
	},
};
