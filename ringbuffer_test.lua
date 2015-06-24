local rb = require'ringbuffer'
local ffi = require'ffi'
io.stdout:setvbuf'no'

--test sweeper
local function _(a0, b0, c0, d0, a1, b1, c1, d1)
	assert(a0 == a1)
	assert(b0 == b1)
	assert(c0 == c1)
	assert(d0 == d1)
end
_( 1,  5,  1,  0, rb.segments( 1,   5, 10))
_( 6,  5,  1,  0, rb.segments( 6,   5, 10))
_( 1, 10,  1,  0, rb.segments( 1,  10, 10))
_(10, -5, 10,  0, rb.segments(10,  -5, 10))
_( 6, -5, 10,  0, rb.segments( 6,  -5, 10))
_(10,-10, 10,  0, rb.segments(10, -10, 10))
_( 6,  5,  1,  5, rb.segments( 6,  10, 10))  --right overflow
_( 5, -5, 10, -5, rb.segments( 5, -10, 10)) --left overflow

--test cdata buffer
local db = rb.cdatabuffer{size = 10, ctype = 'char'}
assert(db.length == 0)
local function _(i, j)
	assert(db.start == i - 1)
	assert((db.start + db.length - 1) % db.size == j - 1)
end
local function nstr(n)
	local b = ffi.new('char[?]', math.abs(n))
	for i=0,n-1 do b[i] = string.byte('A')+i end
	return b, n
end
db:push(nstr(3)) _(1,3)
db:push(nstr(5)) _(1,8)
db:pull(nstr(3)) _(4,8)
db:pull(nstr(-3))_(4,5)
db:push(nstr(3)) _(4,8)
db:push(nstr(5)) _(4,3) --(right overflow)
db:pull(nstr(2)) _(6,3)
db:pull(nstr(-4))_(6,9) --(left underflow)
db:push(nstr(6)) _(6,5) --(right overflow)
assert(db.length == 10)
db:pull(nstr(8)) _(4,5) --(right underflow)
assert(db.length == 2)
db:push(nstr(8)) _(4,3) --(right overflow)
db:pull(nstr(1), 0) --nop
db:push(nstr(1), 0) --nop
assert(db.length == 10)
assert(not pcall(db.push, db, nstr(1)))
--test auto-grow
local backup = ffi.new('char[?]', db.length)
for i=0,db.length-1 do
	backup[i] = db.data[db:offset(i)]
end
db.autogrow = true
local len = db.length
db:push(nstr(15)) _(1,25) --auto-grown
for i=0,len-1 do
	assert(db.data[db:offset(i)] == backup[i])
end

--test value buffer
local vb = rb.valuebuffer{size = 10}
assert(vb.length == 0)
assert(vb.size == 10)
vb:push('a')
vb:push(123)
vb:push(nil)
vb:push(0/0)
vb:push('b')
vb:push{a=1}
assert(vb:pull(-1, 'keep').a == 1)
assert(vb:pull(-1).a == 1)
assert(vb:pull(1, 'keep') == 'a')
assert(vb:pull() == 'a')
assert(vb:pull(-1) == 'b')
assert(vb:pull() == 123)
assert(vb:pull(1, 'keep') == nil)
assert(vb:pull() == nil)
local nan = vb:pull(-1)
assert(nan ~= nan)
assert(vb.length == 0)
--test auto-grow
local function cat(t, sz)
	local dt = {}
	for i=1,sz do dt[i] = t[i] or '.' end
	return table.concat(dt)
end
vb = rb.valuebuffer{size = 4, data = {'d', 'a', 'b', 'c'}, start = 2, length = 4, autogrow = true}
vb:push'e'; assert(cat(vb.data, vb.size) == '.abcde..') --auto-grown; segment 2 moved
vb = rb.valuebuffer{size = 4, data = {'b', 'c', 'd', 'a'}, start = 4, length = 4, autogrow = true}
vb:push'e'; assert(cat(vb.data, vb.size) == 'bcde...a') --auto-grown; segment 1 moved
