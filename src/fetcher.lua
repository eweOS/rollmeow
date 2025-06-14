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
fetcher(url, headers, body)
	local ok, data = coroutine.yield(url, headers, body);

	if not ok then
		error(data);
	else
		return data;
	end
end

local useragent = ("curl/%s (Rollmeow)"):
		  format(cURL.version_info("version"));

local function
readfunc(ctx, size)
	if not ctx.bodyWritten then
		ctx.bodyWritten = true;
		return ctx.body;
	end
end

-- TODO: make it configurable
local function
createHandleWithOpt(data)
	local handle = easy {
				url = data.url,
				httpheader = data.headers,
				[cURL.OPT_TIMEOUT]		= 10,
				[cURL.OPT_LOW_SPEED_LIMIT]	= 10,
				[cURL.OPT_LOW_SPEED_TIME]	= 10,
				[cURL.OPT_FOLLOWLOCATION]	= true,
				[cURL.OPT_USERAGENT]		= useragent,
			    };

	if data.body then
		handle:setopt(cURL.OPT_POST, true);
		handle:setopt_readfunction(readfunc, data);
	end

	handle.data = data;

	return handle;
end

local function
createConn(f, item)
	local co = coroutine.wrap(f);
	local url, headers, body = co(fetcher, item);

	if not url then
		return nil;
	end

	local data = {
			co	= co,
			buf	= {},
			retry	= 0,
			url	= url,
			headers	= headers,
			body	= body,
		     };

	local handle = createHandleWithOpt(data);

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

-- XXX: multi:iperform() doesn't provide a valid iterator in case that no easy
-- handle has been added to the multi instance, thus a for-loop may fail with
-- "attempt to call a nil value". I consider it's a mistake of API design.
-- We provide a wrapper to handle the edge case.
local function
wrapIperform(multi)
	local res = { multi:iperform() };

	if res[1] then
		return table.unpack(res);
	else
		-- End the loop at the first iteration.
		return function(x) return nil; end;
	end
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

	for data, type, handle in wrapIperform(multi) do
		local p = handle.data;
		local newConn = false;

		if type == "error" then
			if p.retry < 3 then
				p.retry = p.retry + 1;
				p.bodyWritten = false;

				verbosef("%s: fetch failed, retry %d",
					 p.url, p.retry);

				handle = createHandleWithOpt(p);

				multi:add_handle(handle);
			else
				p.co(false, tostring(data));
				newConn = true;
			end
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
