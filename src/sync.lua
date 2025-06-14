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
local rmGitProto	= require "gitproto";
local rmPackage		= require "rmpackage";

local gmatch, gsub	= string.gmatch, string.gsub;
local insert		= table.insert;

local pcall, fmtErr = pcall, rmHelper.fmtErr;

local function
normalizeRegex(pattern)
	return gsub(pattern, "%-", "%%-");
end

local function
allMatches(s, pattern)
	local pattern1 = normalizeRegex(pattern);
	return gmatch(s, pattern1);
end

local function
syncByGit(fetcher, pkg)
	local url = pkg.gitrepo;
	if url:sub(-1, -1) == '/' then
		url = url:sub(1, -2);
	end

	url = url .. "/git-upload-pack";

	local headers = {
		"Git-Protocol: version=2",
		"Content-Type: application/x-git-upload-pack-request",
	};
	-- ls-refs command, delim packet and flush packet
	local cmd = '0014command=ls-refs\n00010000';

	local ok, content = pcall(fetcher, url, headers, cmd);
	if not ok then
		return fmtErr("fetch function", content);
	end

	if options.showfetched then
		-- It's likely that Git responses don't end with a newline.
		-- Always add one to avoid messing the terminal up.
		print(content .. '\n');
	end

	local pktlines, msg = rmGitProto.parsePktLine(content);
	if not pktlines then
		return false, msg;
	end

	local matches = {};
	local pattern = normalizeRegex(pkg.regex);
	for _, pktline in ipairs(pktlines) do
		if type(pktline) ~= "string" then
			goto continue;
		end

		local match = pktline:match(pattern);
		if match then
			insert(matches, match);
		end
::continue::
	end

	return matches;
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
	["git"]			= syncByGit,
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
