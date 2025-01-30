local content = assert(io.open(assert(arg[1]), 'r')):read('a');
local regex = assert(io.open(assert(arg[2]), 'r')):read('a');

os.exit(content:match(regex) and 0 or 1);
