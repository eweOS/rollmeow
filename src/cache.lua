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
	local cache = { path = path, news = {} };
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

cacheMeta.close = function(cache)
	if cache.flushed then
		return;
	end

	local cacheF, msg = io.open(cache.path, "a");
	if not cacheF then
		return fmtErr("flushing package cache", msg);
	end

	for pkg, ver in pairs(cache.news) do
		cacheF:write(("v[%q]={%s}\n"):format(pkg, serializeVer(ver)));
	end

	cacheF:close();
	cache.flushed = true;

	return true;
end

-- TODO: update only differs?
cacheMeta.update = function(cache, pkgname, ver)
	cache.news[pkgname] = ver;
end

cacheMeta.query = function(cache, pkgname)
	local ver = cache.news[pkgname];
	if ver then
		return ver;
	end

	return cache.vers[pkgname]
end

return {
	Cache = Cache,
       };
