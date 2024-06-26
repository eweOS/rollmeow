--[[
--	rollmeow
--	/src/helpers.lua
--	SPDX-License-Identifier: MPL-2.0
--	Copyright (c) 2024 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local string		= require "string";

local function
validateTable(expect, obj)
	if type(obj) ~= "table" then
		return false, "not a table";
	end

	for k, constraints in pairs(expect) do
		local v = obj[k];
		if not v then
			if constraints.optional then
				goto continue;
			end

			return false, "missing field " .. k;
		end

		if type(v) ~= constraints.type then
			return false,
				("type mismatch for %s: expect %s, got %s"):
				format(k, constraints.type, type(v));
		end
::continue::
	end

	return true;
end

return {
	validateTable	= validateTable,
       };
