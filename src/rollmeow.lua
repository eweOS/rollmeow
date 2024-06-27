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
	return s:match(pattern:gsub("%-", "%%-"));
end

local conf = safeDoFile(gConfPath);
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
cmdSync(arg)
	local pkg = conf.packages[arg[2]];
	if not pkg then
		perrf("package %s not found", arg[2]);
	end

	local ok, ret = rmSync.sync(fetchUpstream, pkg);

	if ok then
		print(rmVersion.verString(ret));
	else
		pwarnf("%s: failed to sync: %s", arg[2], ret);
	end
end

local function
cmdReport()
end

local function
cmdHelp()
	io.stderr:write(
[==[
Usage: rollmeow [options] <sync|report>
]==]);
end

local cmds = {
	sync	= cmdSync,
	report	= cmdReport,
	help	= cmdHelp,
};

if not arg[1] then
	cmdHelp();
	os.exit(-1);
end

local cmd = cmds[arg[1]];
if not cmd then
	pwarnf("Unknown command %s", cmd);
	cmdHelp();
	os.exit(-1);
else
	cmd(arg);
end
