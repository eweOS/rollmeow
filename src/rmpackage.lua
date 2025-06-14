--[[
--	rollmeow
--	/src/rmpackage.lua
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2025 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local table		= require "table";

local function
alignedFormat(n, k, v)
	return ("%s:%s%s"):format(k, (' '):rep(n - #k - 1), v);
end

local function
prettyPrint(name, pkg)
	local pkgAttrs = { "url", "regex", "note", "follow" };
	local buf = { ("name:\t\t%s"):format(name) };

	for _, attr in ipairs(pkgAttrs) do
		local value = pkg[attr];
		if value then
			table.insert(buf, alignedFormat(16, attr, value));
		end
	end

	return table.concat(buf, '\n') .. '\n';
end

local function
pkgType(pkg)
	local url, gitrepo = pkg.url, pkg.gitrepo;
	local regex, follow = pkg.regex, pkg.follow;

	if url and not gitrepo and regex and not follow then
		return "regex-match";
	elseif not url and gitrepo and regex and not follow then
		return "git";
	elseif not gitrepo and not regex and follow then
		return "batched";
	elseif url and not gitrepo and not regex and not follow then
		return "manual";
	end

	return nil;
end

return {
	prettyPrint	= prettyPrint,
	type		= pkgType,
       };
