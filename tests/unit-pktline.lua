local rmGitProto	= require "gitproto";

local parsePktLine = rmGitProto.parsePktLine;
local flushPkt, delimPkt = rmGitProto.flushPkt, rmGitProto.delimPkt;
local connEndPkt = rmGitProto.connEndPkt;

local function
cmpResult(got, expected)
	assert(#got == #expected,
	       ("#got = %d, #expected = %d"):format(#got, #expected));

	for i = 1, #got do
		assert(got[i] == expected[i],
		       ("msg %d: got '%s'"):format(i, got[i]));
	end
end

-- Examples from Git documentation
cmpResult(assert(parsePktLine "0006a\n"),	{ "a\n" });
cmpResult(assert(parsePktLine "0005a"),		{ "a" });
cmpResult(assert(parsePktLine "000bfoobar\n"),	{ "foobar\n" });
cmpResult(assert(parsePktLine "0004"),		{ "" });

-- Special pktlines
cmpResult(assert(parsePktLine "0000"), { flushPkt });
cmpResult(assert(parsePktLine "0001"), { delimPkt });
cmpResult(assert(parsePktLine "0002"), { connEndPkt });
-- with following data
cmpResult(assert(parsePktLine "00000005a"), { flushPkt, "a" });

-- Junk data at the end
local ret, msg = parsePktLine "0005a0005ab";
assert(ret == false and msg == "error in pkt-line data: junk at the end",
       ("got ret = %s, msg = %s"):format(ret, msg));

-- A typical server response from GitHub
cmpResult(assert(parsePktLine [[
0032a001433835207d81b21a6ad6aa0a7f0b6cebb686 HEAD
003da001433835207d81b21a6ad6aa0a7f0b6cebb686 refs/heads/main
0000]]),
	{ "a001433835207d81b21a6ad6aa0a7f0b6cebb686 HEAD\n",
	  "a001433835207d81b21a6ad6aa0a7f0b6cebb686 refs/heads/main\n",
	  flushPkt });

-- A (relatively large) typical server response from gitlab.freedesktop.org,
-- serving as a performance test as well.
local response = io.open(os.getenv("TESTDIR") .. "/fdo-wlroots-response.txt"):
		 read('a');
for i = 1, 100 do
	assert(parsePktLine(response));
end
