--[[
--	rollmeow
--	/src/fetcher.lua
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2024 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local coroutine			= require "coroutine";
local string			= require "string";
local table			= require "table";

local cURL			= require "cURL";

local rmHelpers			= require "helpers"

local yield, easy	= coroutine.yield, cURL.easy;
local insert, remove	= table.insert, table.remove;
local concat		= table.concat;
local verbosef		= rmHelpers.verbosef;

local function
fetcher(url)
	local ok, data = coroutine.yield(url);

	if not ok then
		error(data);
	else
		return data;
	end
end

-- TODO: make it configurable
local function
createHandleWithOpt(url)
	return easy {
			url = url,
			[cURL.OPT_TIMEOUT]		= 10,
			[cURL.OPT_LOW_SPEED_LIMIT]	= 10,
			[cURL.OPT_LOW_SPEED_TIME]	= 10,
			[cURL.OPT_FOLLOWLOCATION]	= true,
		    };
end

local function
createConn(f, item)
	local co = coroutine.wrap(f);
	local url = co(fetcher, item);

	if not url then
		return nil;
	end

	local handle = createHandleWithOpt(url);
	handle.data = { co = co, buf = {}, retry = 0, url = url };
	return handle;
end

local function
nextConn(f, list)
	while list[1] do
		local handle = createConn(f, list[#list]);
		table.remove(list);
		if handle then
			return handle;
		end
	end

	return nil;
end

-- TODO: make retry configurable
local function
forEach(connections, f, originList)
	local list = {};
	for i = #originList, 1, -1 do
		list[#originList - i + 1] = originList[i];
	end

	local multi = cURL.multi();
	for i = 1, connections do
		local handle = nextConn(f, list);
		if not handle then
			break;
		end

		multi:add_handle(handle);
	end

	for data, type, handle in multi:iperform() do
		local p = handle.data;
		local newConn = false;

		if type == "error" then
			if p.retry < 3 then
				p.retry = p.retry + 1;
				verbosef("%s: sync failed, retry %d",
					 p.url, p.retry);
				handle = createHandleWithOpt(p.url);
				handle.data = p;
				multi:add_handle(handle);
			else
				p.co(false, tostring(data));
				newConn = true;
			end
		elseif type == "done" then
			insert(p.buf, data);
			p.co(true, concat(p.buf));
			newConn = true;
		elseif type == "data" then
			insert(p.buf, data);
		end

		if newConn then
			local handle = nextConn(f, list);
			if handle then
				multi:add_handle(handle);
			end
		end
	end
end

return {
	forEach = forEach,
       };
