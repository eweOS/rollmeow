--[[
--	rollmeow
--	/src/cache.lua
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2024 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local io		= require "io";
local string		= require "string";

local rmHelpers		= require "helpers";
local rmVersion		= require "version";

local fmtErr = rmHelpers.fmtErr;

local function
recreateCache(path)
	local cacheFile, msg = io.open(path, "w");
	if not cacheFile then
		return fmtErrmsg("creating cache file", msg);
	end

	cacheFile:write("local v = {};\n");
	cacheFile:close();

	return true;
end

local cacheMeta = {};
cacheMeta.__index = cacheMeta;

local function
Cache(path)
	local cache = { path = path, news = {}, deleted = {} };
	local cacheFile, msg = io.open(path, "r");

	if cacheFile then
		local rawCache = cacheFile:read("a") .. "return v";
		local cacheF, msg = load(rawCache);
		if not cacheF then
			return fmtErr("loading cache", msg);
		end

		local ok, ret = pcall(cacheF);
		if not ok then
			return fmtErr("loading cache", msg);
		end

		-- TODO: validate cache
		cache.vers = ret;
	else
		local ok, msg = recreateCache(path);
		if not ok then
			return false, msg;
		end
		cache.vers = {};
	end

	return setmetatable(cache, cacheMeta);
end

local function
serializeVer(v)
	local s = '"' .. v[1] .. '"';
	for i = 2, #v do
		s = s .. ',"' .. v[i] .. '"';
	end
	return s;
end

cacheMeta.flush = function(cache)
	local cacheF, msg = io.open(cache.path, "a");
	if not cacheF then
		return fmtErr("flushing package cache", msg);
	end

	for pkg, ver in pairs(cache.news) do
		cacheF:write(("v[%q]={%s}\n"):format(pkg, serializeVer(ver)));
	end

	for pkg, _ in pairs(cache.deleted) do
		cacheF:write(("v[%q]=nil\n"):format(pkg));
	end

	cacheF:close();
	return true;
end

local vCmp = rmVersion.cmp;
cacheMeta.update = function(cache, pkgname, ver)
	local old = cache.vers[pkgname];
	if old and vCmp(old, ver) == 0 then
		return;
	end
	cache.news[pkgname] = ver;
end

cacheMeta.delete = function(cache, pkgname)
	cache.deleted[pkgname] = true;
end

cacheMeta.query = function(cache, pkgname)
	if cache.deleted[pkgname] then
		return nil;
	end

	local ver = cache.news[pkgname];
	if ver then
		return ver;
	end

	return cache.vers[pkgname]
end

return {
	Cache = Cache,
       };
