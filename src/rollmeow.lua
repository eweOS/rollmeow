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

local gConfPath <const>	= "./rollmeow.cfg.lua";

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

	-- TODO: Run in sandbox
	local fcfg, msg = load(f:read("a"));
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
doMatch(s, pattern)
	return s:match(pattern);
end


if #arg ~= 1 then
	perrf("Usage:\n\trollmeow <PKGNAME>");
end

local conf = safeDoFile(gConfPath);

local fetchUpstream = conf.fetchUpstream;
local evalDownstrean = conf.evalDownstream;

for name, pkg in pairs(conf.items) do
	local upver = doMatch(conf.fetchUpstream(pkg.url), pkg.regex);
	if not upver then
		pwarnf("%s: No match on upstream", name);
		goto continue
	end
	local downver = conf.evalDownstream(name);
	print(("%s: upstream - %s, downstream %s"):format(name, upver, downver));
::continue::
end
