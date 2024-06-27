--[[
--	rollmeow
--	/src/sync.lua
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2024 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local string		= require "string";
local table		= require "table";
local rmVersion		= require "version";
local rmHelper		= require "helpers";

local gmatch, gsub	= string.gmatch, string.gsub;
local insert		= table.insert;

local function
allMatches(s, pattern)
	local pattern1 = gsub(pattern, "%-", "%%-");
	return gmatch(s, pattern1);
end

local vCmp = rmVersion.cmp;
local function
latestVersion(vers)
	local latest = vers[1];
	for i = 2, #vers do
		if vCmp(vers[i], latest) > 0 then
			latest = vers[i];
		end
	end
	return latest;
end

local pcall = pcall;
local vConvert = rmVersion.convert;
local fmtErr = rmHelper.fmtErr;
local function
sync(fetcher, pkg)
	local ok, content = pcall(fetcher, pkg.url);
	if not ok then
		return fmtErr("fetch function", content);
	end

	local postMatch, filter = pkg.postMatch, pkg.filter;
	local vers = {};
	for match in allMatches(content, pkg.regex) do
		if postMatch then
			local ok, ret = pcall(postMatch, match);
			if not ok then
				return fmtErr("postMatch hook", ret);
			end

			if type(ret) ~= "string" then
				return false,
				  "postMatch hook returns a " .. type(ret);
			end

			match = ret;
		end

		local ver = vConvert(match);
		local valid = true;
		if filter then
			local ok, ret = pcall(filter, ver);

			if not ok then
				return fmtErr("filter hook", ret);
			end

			valid = ret;
		end

		if valid then
			insert(vers, ver);
		end
	end

	if #vers == 0 then
		return false, "no valid match in upstream";
	end

	return true, latestVersion(vers);
end

return {
	sync = sync,
       };
