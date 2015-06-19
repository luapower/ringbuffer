local rb = require'ringbuffer'
local ffi = require'ffi'

--test sweeper
local function _(a0, b0, c0, d0, a1, b1, c1, d1)
	print(a1, b1, c1, d1)
	assert(a0 == a1)
	assert(b0 == b1)
	assert(c0 == c1)
	assert(d0 == d1)
end
_(1,  5, 1, 0, rb.segments(1, 5, 10))
_(6,  5, 1, 0, rb.segments(6, 5, 10))
_(1, 10, 1, 0, rb.segments(1, 10, 10))
_(10,-5,10, 0, rb.segments(10, -5, 10))
_(6, -5,10, 0, rb.segments(6, -5, 10))
_(10,-10,10,0, rb.segments(10, -10, 10))
_(6,  5, 1, 5, rb.segments(6, 10, 10))  --right overflow
_(5, -5,10,-5, rb.segments(5, -10, 10)) --left overflow

--test API
local b = rb.buffer(10)
assert(b:length() == 0)
assert(b:isempty())
assert(b:size() == 10)
for i,n in b:segments() do
	assert(false) --should have no segments
end

--test state
function b:_write(...) print('write', ...) end
function b:_read(...) print('read', ...) end
local function _(i,j)
	assert(b._start == i)
	assert((b._start + b._length - 1) % b._size == j)
end
b:push('', 3) _(1,3)
b:push('', 5) _(1,8)
b:shift(3)    _(4,8)
b:pop(3)      _(4,5)
b:push('', 3) _(4,8)
b:push('', 5) _(4,3) --(right overflow)
b:shift(2)    _(6,3)
b:pop(4)      _(6,9) --(left underflow)
b:push('', 6) _(6,5) --(right overflow)
assert(b:length() == 10)
b:shift(8)    _(4,5) --(right underflow)
assert(b:length() == 2)
b:push('', 8) _(4,3) --(right overflow)
for i,n in b:segments() do
	print('segment: ', i, n)
end

--test value buffers
local vb = rb.valuebuffer(10)
assert(vb:length() == 0)
assert(vb:size() == 10)
vb:push('a')
vb:push(123)
vb:push('b')
vb:push{a=1}
assert(vb:pop().a == 1)
assert(vb:shift() == 'a')
assert(vb:pop() == 'b')
assert(vb:shift() == 123)
assert(vb:length() == 0)
