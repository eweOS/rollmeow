#!/usr/bin/env lua5.4

--[[
--	rollmeow
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2024 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information
--]]

local io		= require "io";
local os		= require "os";
local string		= require "string";

local rmHelpers		= require "helpers";
local rmVersion		= require "version";
local rmSync		= require "sync";
local rmCache		= require "cache";

--[[	TODO: move these functions to helpers	]]
local function
pwarn(msg)
	io.stderr:write(msg .. "\n");
end

local function
perr(msg)
	pwarn(msg);
	os.exit(-1);
end

local function
perrf(msg, ...)
	perr(string.format(msg, ...));
end

local function
pwarnf(msg, ...)
	pwarn(string.format(msg, ...));
end

local function
safeDoFile(path)
	local f, msg = io.open(path, "r");
	if not f then
		perrf("Cannot load configuration:\n %s", msg);
	end

	local env = {};
	env._G = env;
	local fcfg, msg = load(f:read("a"), path, "t",
			       setmetatable(env, { __index = _G }));
	if not fcfg then
		perrf("Cannot parse configuration:\n%s", msg);
	end

	local ok, ret = pcall(fcfg);
	if not ok then
		perrf("Cannot eval configuration:\n%s", ret);
	end

	return ret;
end

local function
printHelp()
	io.stderr:write(
[==[
Usage: rollmeow [options] [PKGNAME1] [PKGNAME2] ...
]==]);
end

-- global options
options = {
	sync		= false,
	diff		= false,
	json		= false,
	help		= false,
	verbose		= false,
	showmatch	= false,
	conf	= os.getenv("HOME") .. "/.config/rollmeow/rollmeow.cfg.lua",
};
local i, pkgs = 1, {};
while i <= #arg do
	local s = arg[i];
	if s:sub(1, 2) == "--" then
		s = s:sub(3, -1);	-- strip "--"

		local v = options[s];
		if v == nil then
			perrf("Unknown option %s", s);
		end

		if type(v) == "boolean" then
			options[s] = not v;
		elseif type(v) == "string" then
			if i + 1 > #arg then
				perrf("Option %s requires an argument", s);
			end
			i = i + 1;
			options[s] = arg[i];
		end
	else
		table.insert(pkgs, arg[i]);
	end
	i = i + 1;
end

if options.help then
	printHelp();
	os.exit(0);
end

local conf = safeDoFile(options.conf);
local confFormat = {
	evalDownstream	= { type = "function" },
	fetchUpstream	= { type = "function" },
	cachePath	= { type = "string" },
	packages	= { type = "table" },
};
local ok, msg = rmHelpers.validateTable(confFormat, conf);
if not ok then
	perrf("Invalid configuration: %s", msg);
end

local cache, msg = rmCache.Cache(conf.cachePath);
if not cache then
	perr(msg);
end

local pkgFormat = {
	url		= { type = "string" },
	regex		= { type = "string" },
	postMatch	= { type = "function", optional = true },
	filter		= { type = "function", optional = true },
};
for name, pkg in pairs(conf.packages) do
	local ok, msg = rmHelpers.validateTable(pkgFormat, pkg);
	if not ok then
		perrf("Invalid package %s: %s", name, msg);
	end
end

local fetchUpstream = conf.fetchUpstream;
local evalDownstrean = conf.evalDownstream;

local function
doSync(name)
	local pkg = conf.packages[name];
	if not pkg then
		perrf("%s: not found", name);
	end

	local ok, ret;
	for i = 1, 5 do
		ok, ret = rmSync.sync(fetchUpstream, pkg);
		if ok then
			break;
		end
		if options.verbose then
			pwarnf(("%s: failed to sync, retry %d"):format(name, i));
		end
	end

	if ok then
		cache:update(name, ret);
	else
		pwarnf("%s: failed to sync: %s", name, ret);
	end
end

local function
doReport(name)
	local pkg = conf.packages[name];
	if not pkg then
		perrf("%s: not found", name);
	end

	local upVer = cache:query(name);
	if not upVer then
		pwarnf("%s: not cached", name);
		return;
	end

	local ok, downStr = pcall(conf.evalDownstream, name);
	if not downStr then
		pwarnf("%s: failed to eval downstream version: %s", name, downVer);
		return;
	end

	local downVer = rmVersion.convert(downStr);
	if options.diff and rmVersion.cmp(downVer, upVer) == 0 then
		return;
	end

	local upStr = rmVersion.verString(upVer);
	print(("%s: upstream %s | downstream %s"):format(name, upStr, downStr));
end


--[[	enumerate all packages	]]
if #pkgs == 0 then
	for name, _ in pairs(conf.packages) do
		table.insert(pkgs, name);
	end
	table.sort(pkgs);
end

if options.sync then
	for _, pkg in ipairs(pkgs) do
		if options.verbose then
			pwarnf("syncing %s", pkg);
		end
		doSync(pkg);
	end

	local ok, ret = cache:flush();
	if not ok then
		pwarn(ret);
	end
end

for _, pkg in ipairs(pkgs) do
	doReport(pkg);
end
