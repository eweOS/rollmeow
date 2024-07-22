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

local yield, easy	= coroutine.yield, cURL.easy;
local insert, remove	= table.insert, table.remove;
local concat		= table.concat;

local function
fetcher(url)
	local ok, data = coroutine.yield(url);

	if not ok then
		error(data);
	else
		return data;
	end
end

local function
createConn(f, item)
	local co = coroutine.wrap(f);
	local url = co(fetcher, item);

	if not url then
		return nil;
	end

	local handle = easy{ url = url };
	handle.data = { co = co, buf = {}, retry = 0 };
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
			p.co(false, tostring(data));
			newConn = true;
		elseif type == "done" then
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
