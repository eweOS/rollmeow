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
local rmFetcher		= require "fetcher";

local pwarn, perr	= rmHelpers.pwarn, rmHelpers.perr;
local pwarnf, perrf	= rmHelpers.pwarnf, rmHelpers.perrf;
local verbose, verbosef	= rmHelpers.verbose, rmHelpers.verbosef;

local function
safeDoFile(path)
	local f, msg = io.open(path, "r");
	if not f then
		perrf("Cannot load configuration %s:\n%s", path, msg);
	end

	local env = {};
	env._G = env;
	local fcfg, msg = load(f:read("a"), path, "t",
			       setmetatable(env, { __index = _G }));
	if not fcfg then
		perrf("Cannot parse configuration %s:\n%s", path, msg);
	end

	local ok, ret = pcall(fcfg);
	if not ok then
		perrf("Cannot eval configuration %s:\n%s", path, ret);
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
	info		= false,
	manual		= false,
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

if options.verbose then
	rmHelpers.setVerbose(options.verbose);
end

local conf = safeDoFile(options.conf);
local confFormat = {
	evalDownstream	= { type = "function" },
	cachePath	= { type = "string" },
	packages	= { type = "table" },
	connections	= { type = "number", optional = true },
	timeout		= { type = "numner", optional = true },
};
local ok, msg = rmHelpers.validateTable(confFormat, conf);
if not ok then
	perrf("Invalid configuration: %s", msg);
end

if conf.fetchUpstream then
	pwarn "From 0.2.0, rollmeow drops `fetchUpstream` in configuration.";
	pwarn "Use default concurrent fetcher instead.";
end

local cache, msg = rmCache.Cache(conf.cachePath);
if not cache then
	perr(msg);
end

local pkgFormat = {
	url		= { type = "string" },
	regex		= { type = "string", optional = true },
	postMatch	= { type = "function", optional = true },
	filter		= { type = "function", optional = true },
};
for name, pkg in pairs(conf.packages) do
	local ok, msg = rmHelpers.validateTable(pkgFormat, pkg);
	if not ok then
		perrf("Invalid package %s: %s", name, msg);
	end
end

local evalDownstrean = conf.evalDownstream;

local function
doSync(fetcher, name)
	local pkg = conf.packages[name];
	if not pkg then
		perrf("%s: not found", name);
	elseif not pkg.regex then
		verbosef("skip %s, please check manually", name);
		return;
	end
	verbosef("syncing %s...", name);

	local ok, ret = rmSync.sync(fetcher, pkg);
	if not ok then
		pwarnf("%s: failed to sync: %s",
		       name, ret or "no information");
		cache:delete(name);
		return;
	end

	cache:update(name, ret);
end

local function
jsonVer(ver)
	local v = "[ " .. ("%q"):format(ver[1]);
	for i = 2, #ver do
		v = v .. ", " .. ("%q"):format(ver[i]);
	end

	return v .. " ]";
end

local function
pkgJSON(status, name, up, down, note)
	local statusStr = status == 0 and "ok" or "outofdate";
	local downStr = jsonVer(down);
	local upStr = up == "MANUAL" and ("%q"):format(up) or jsonVer(up);
	local noteStr = note ~= nil and (', "note": %q '):format(note) or "";
	return
	  ('{ "name": %q, "status": %q, "upstream": %s, "downstream": %s %s}'):
	       format(name, statusStr, upStr, downStr, noteStr);
end

local function
reportPkg(status, name, up, down, note)
	if options.json then
		return pkgJSON(status, name, up, down, note);
	else
		local upStr = up == "MANUAL" and up or rmVersion.verString(up);
		local downStr = rmVersion.verString(down);
		return ("%s%s: upstream %s | downstream %s"):
		       format(name, note ~= nil and "[!]" or "",
		              upStr, downStr);
	end
end

local function
jsonFailed(name, reason)
	return ('{ "name": %q, "status": "failed", "reason": %q }'):
	       format(name, reason);
end

local function
doReport(name)
	local pkg = conf.packages[name];
	if not pkg then
		perrf("%s: not found", name);
	end

	if not pkg.regex and not options.manual then
		return;
	end

	local ok, downStr = pcall(conf.evalDownstream, name);
	if not downStr then
		if not options.json then
			pwarnf("%s: failed to eval downstream version: %s",
			       name, downVer);
			return;
		else
			return jsonFailed(name, "failed to eval downstream");
		end
	end

	local downVer = rmVersion.convert(downStr);

	local upVer, status = "MANUAL", 1;
	if pkg.regex then
		upVer = cache:query(name);
		if not upVer then
			if not options.json then
				pwarnf("%s: not cached", name);
				return;
			else
				return jsonFailed(name, "not cached");
			end
		end

		status = rmVersion.cmp(downVer, upVer);
		if options.diff and status == 0 then
			return;
		end
	end

	return reportPkg(status, name, upVer, downVer, pkg.note);
end

local function
alignedFormat(n, k, v)
	return ("%s:%s%s"):format(k, (' '):rep(n - #k - 1), v);
end

local function
pkginfo(name)
	local pkg = conf.packages[name];
	if not pkg then
		perrf("%s: not found", name);
	end

	local pkgAttrs = { "url", "regex", "note" };
	print(("name:\t\t%s"):format(name));
	for _, attr in ipairs(pkgAttrs) do
		if pkg[attr] then
			print(alignedFormat(16, attr, pkg[attr]));
		end
	end
end

if options.info then
	if #pkgs == 0 then
		perrf("option --info must come with package names");
	end

	for i, pkg in ipairs(pkgs) do
		if i ~= 1 then
			io.stdout:write('\n');
		end

		pkginfo(pkg);
	end

	os.exit(0);
end

--[[	enumerate all packages	]]
if #pkgs == 0 then
	for name, _ in pairs(conf.packages) do
		table.insert(pkgs, name);
	end
	table.sort(pkgs);
end

if options.sync then
	rmFetcher.forEach(conf.connections or 8, doSync, pkgs);

	local ok, ret = cache:flush();
	if not ok then
		pwarn(ret);
	end
end

local output = {};
for _, pkg in ipairs(pkgs) do
	local s = doReport(pkg);
	if s then
		if options.json then
			table.insert(output, s);
		else
			print(s);
		end
	end
end

if options.json then
	print("[");
	print(table.concat(output, ",\n"));
	print("]");
end
