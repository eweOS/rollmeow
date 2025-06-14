-- SPDX-License-Identifier: MPL-2.0
--[[
--	rollmeow
--	/src/gitproto.lua
--	Copyright (C) 2025 eweOS developers. All rights reserved.
--	Refer to https://os.ewe.moe/ for more information.
--]]

local string		= require "string";
local table		= require "table";

local fmtErr		= require "helpers".fmtErr;

--[[
--	Summarized from Git's documentation gitprotocol-common.adoc
--
--		HEXDIG		= DIGIT / "a" / "b" / "c" / "d" / "e" / "f"
--		pkt-line	= data-pkt / flush-pkt
--
--		data-pkt	= pkt-len pkt-payload
--		pkt-len		= 4*(HEXDIG)
--		pkt-payload	= (pkt-len - 4)*(OCTET)
--
--		flush-pkt	= "0000"
--
--	and from gitprotocol-v2.adoc
--
-- > In protocol v2 these special packets will have the following semantics:
-- >   * '0000' Flush Packet (flush-pkt) - indicates the end of a message
-- >   * '0001' Delimiter Packet (delim-pkt) - separates sections of a message
-- >   * '0002' Response End Packet (response-end-pkt) - indicates the end of a
-- >	  response for stateless connections
--]]

local flushPkt, delimPkt, connEndPkt = {}, {}, {};

local specialPktLineLBT = {
	[0] = flushPkt,
	[1] = delimPkt,
	[2] = connEndPkt,
};

local function
matchPktLine(bin, pos)
	return bin:match("^([0-9a-f][0-9a-f][0-9a-f][0-9a-f])()", pos)
end

local function
parsePktLine(bin)
	-- pos keeps track of the data that we've already decoded. It's
	-- impratical to split the data (actual a string) each time we decode
	-- a part, which leads to O(n^2) complexitiy in time thanks to
	-- immutable strings.
	local npktline, pos = 0, 1;
	local pktlines = {};

	while true do
		local pktlen, newpos = matchPktLine(bin, pos);
		if not newpos then
			break;
		end

		pos = newpos;
		pktlen = tonumber("0x" .. pktlen);
		npktline = npktline + 1;

		local specialPktLine = specialPktLineLBT[pktlen];
		if specialPktLine then
			pktlines[npktline] = specialPktLine;
		else
			pktlen = pktlen - 4;

			local data = bin:sub(pos, pos + pktlen - 1);
			pos = pos + pktlen;

			if #data ~= pktlen then
				local msg = ("invalid pkt-len %d, " ..
					     "data ends at byte %d"):
					    format(pktlen, #data);

				return fmtErr("pkg-line data", msg);
			end

			pktlines[npktline] = data;
		end
	end

	if pos == #bin + 1 then
		return pktlines;
	else
		return fmtErr("pkt-line data", "junk at the end");
	end
end

return {
	flushPkt	= flushPkt,
	delimPkt	= delimPkt,
	connEndPkt	= connEndPkt,
	parsePktLine	= parsePktLine,
       };
