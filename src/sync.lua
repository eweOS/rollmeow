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
local rmPackage		= require "rmpackage";

local gmatch, gsub	= string.gmatch, string.gsub;
local insert		= table.insert;

local pcall, fmtErr = pcall, rmHelper.fmtErr;

local function
allMatches(s, pattern)
	local pattern1 = gsub(pattern, "%-", "%%-");
	return gmatch(s, pattern1);
end

local function
syncByRegexMatch(fetcher, pkg)
	local ok, content = pcall(fetcher, pkg.url);
	if not ok then
		return fmtErr("fetch function", content);
	end

	local matches = {};

	if options.showfetched then
		rmHelper.pwarn(content .. '\n');
	end

	for match in allMatches(content, pkg.regex) do
		table.insert(matches, match);
	end

	return matches;
end

local syncImplLUTByType <const> = {
	["regex-match"]		= syncByRegexMatch,
};

local function
getSyncImpl(pkg)
	local t = rmPackage.type(pkg);

	return t and syncImplLUTByType[t];
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

local vConvert = rmVersion.convert;
local function
sync(fetcher, pkg)
	local syncImpl = getSyncImpl(pkg);
	if not syncImpl then
		return fmtErr("package description", "invalid package type");
	end

	local entries, msg = syncImpl(fetcher, pkg);
	if not entries then
		return false, msg;
	end

	local postMatch, filter = pkg.postMatch, pkg.filter;
	local vers = {};
	for _, match in ipairs(entries) do
		if options.showmatch then
			rmHelper.pwarn(match .. "\n");
		end

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
