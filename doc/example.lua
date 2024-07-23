local pkgs = {};

pkgs["abseil-cpp"] = {
	url = "https://github.com/abseil/abseil-cpp/tags",
	regex = "(%d%d%d%d%d%d%d%d%.%d).tar.gz"
};

local function
evalDownstream(pkg)
	local cmd = ("pacman -Q %s | cut -d ' ' -f 2"):format(pkg);
	local output = io.popen(cmd, "r"):read("a");
	local ver = output:match("(.-)%-%d+");
	return ver;
end

return
{
	evalDownstream	= evalDownstream,
	fetchUpstream	= fetchUpstream,
	cachePath	= "rollmeow.cache.lua",
	packages	= pkgs,
	connections	= 4,
};
