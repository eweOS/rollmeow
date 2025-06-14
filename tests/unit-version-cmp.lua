local vcmp = require "version".cmp;

local v123 = { "3", "2", "1" };
local v321 = { "1", "2", "3" };

assert(vcmp(v123, v321) == 1);
assert(vcmp(v321, v123) == -1);
assert(vcmp(v123, v123) == 0);

-- Version components are compared as integer first, and as string if
-- it fails. So 1.beta9 > 1.beta16 is expected, but 1.beta.9 < 1.beta.16
assert(vcmp({ "1", "beta9" }, { "1", "beta16" }) > 0);
assert(vcmp({ "1", "beta", "9" }, { "1", "beta", "16" }) < 0);

-- The one with more components always wins
assert(vcmp({ "1", "2", "1" }, { "1", "2" }) > 0);
assert(vcmp({ "1", "2", "0" }, { "1", "2" }) > 0);
assert(vcmp({ "1", "2" }, { "1", "2", "0" }) < 0);
