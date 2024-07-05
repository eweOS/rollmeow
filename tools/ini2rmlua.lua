#!/usr/bin/env lua5.4

--[[
--	convert archversion .ini configuration to
--	rollmeow pkglist.
--	usage:
--		lua5.4 ini2rmlua.lua INIFILE
--]]

local io		= require "io";
local string		= require "string";
local os		= require "os";
local table		= require "table";

assert(#arg == 1);

local insert = table.insert;
local iniF = io.open(arg[1], "r");
local items = {};
local item = {};
local i = 1;
for l in iniF:lines() do
	if l:sub(1, 1) == '#' then
		goto continue;
	end

	if l == "" then
		if item[1] ~= "[DEFAULT]" and #item ~= 0 then
			insert(items, item);
		end
		item = {};
	else
		insert(item, (l:gsub("^#", "")));
	end
::continue::
end
insert(items, item);
iniF:close();

local function
extractField(s)
	return s:match("([%w_]+)%s*%=%s*(.+)");
end

local function
convertRegex(s)
	local s1 = s:gsub("\\", "%%");
--	local s2 = s1:gsub("%-", "%%-");
	return s1;
end

for _, pkg in pairs(items) do
	-- extract names
	local name = pkg[1]:match("%[(.+)%]");
	if not name then
		print(("misformed package name %s"):format(pkg[1]));
	end
	pkg.name = name;

	-- extract fields
	for i = 2, #pkg do
		local raw = pkg[i]
		local k, v = extractField(raw);
		if not k or not v then
			print(("%s: misformed line %s"):format(name, raw));
		end
		pkg[k] = v;
	end

	if pkg.regex then
		-- convert regex
		pkg.regex = convertRegex(pkg.regex);
	end
end

local function
printKV(k, v)
	print(('\t%s\t= "%s",'):format(k, v));
end

-- write results
for _, v in ipairs(items) do
	print(('pkgs[%q] = {'):format(v.name));
	printKV("url", v.url);

	printKV("regex", v.regex or '(%d+%.%d+%.%d+).tar.gz');

	-- require manual fixup
	if v.eval_upstream then
		print("\t-- FIXME");
		print("\t-- eval_upstream = " .. v.eval_upstream);
	end

	print("};\n");
end
