--[[
--	rollmeow
--	/src/version.lua
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2024 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local math		= require "math";
local string		= require "string";

local min = math.min;

local function
cmp(v1, v2)
	for i = 1, min(#v1, #v2) do
		local a, b = v1[i], v2[i];
		local a1, b1 = tonumber(a), tonumber(b);

		if a == b then
			goto continue;
		elseif a1 and b1 then
			return a1 > b1 and 1 or -1;
		elseif a1 then
			return 1;
		elseif b1 then
			return -1;
		else
			return a > b and 1 or -1;
		end
::continue::
	end

	return #v1 == #v2 and 0 or
	       #v1 >  #v2 and 1 or
	       #v1 <  #v2 and -1;
end

local gmatch = string.gmatch;
local function
convert(s)
	local r = { "" };
	local i = 1;
	for vs in gmatch(s, "[^%.]+") do
		r[i] = vs;
		i = i + 1;
	end
	return r;
end

local function
verString(v)
	local s = tostring(v[1]);
	for i = 2, #v do
		s = s .. '.' .. tostring(v[i]);
	end
	return s;
end

return {
	cmp		= cmp,
	convert		= convert,
	verString	= verString,
       };
