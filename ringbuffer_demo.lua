local rb = require'ringbuffer'
local ffi = require'ffi'
local rand = math.random
io.stdout:setvbuf'no'

local b = rb.cdatabuffer{ctype = 'char', size = 50}

local function randstr(n)
	return ffi.cast('const char*', string.char(rand(('A'):byte(), ('Z'):byte())):rep(n))
end

math.randomseed(os.time())

for i = 1, 1000 do

	local n = math.floor(rand(-b.length, b.size - b.length) / rand(16))
	if rand() > 0.9 then --hit full
		n = b.size - b.length
	elseif rand() < 0.1 then --hit empty
		n = -b.length
	end
	if n > 0 then
		b:push(randstr(n), n)
	elseif n < 0 then
		b:pull(n * (rand() > .5 and 1 or -1), function() end)
	end

	local i1, n1, i2, n2 = rb.segments(b.start + 1, b.length, b.size)
	local s = ffi.string(b.data, b.length)
	if n2 == 0 then
		print(('.'):rep(i1 -1)..s..('.'):rep(b.size - (i1 + n1) + 1),
			string.format('%2d-%2d', i1, i1 + n1 - 1))
	else
		print(s:sub(n1 + 1)..('.'):rep(b.size - n1 - n2)..s:sub(1, n1),
			string.format('%2d-%2d, %2d-%2d', i1, i1 + n1 - 1, i2, i2 + n2 - 1))
	end
end
