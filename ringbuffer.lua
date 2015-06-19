
-- FIFO/LIFO Ring Buffers.
-- Written by Cosmin Apreutesei. Public Domain.

local min, max, abs = math.min, math.max, math.abs

--normalize an index if it exceeds buffer size up to twice-1
local function normalize(i, size)
	return i > size and i - size or i
end

--the heart of the algorithm: sweep an arbitrary arc over a circle, returning
--one or two of the normalized arcs that map the input arc to the circle.
--the buffer segment (start, length) is the arc in the model, and a buffer
--ring (1, size) is the circle. `start` must be normalized to (1, size).
--`length` can be positive or negative and can't exceed `size`. the second
--output segment can have zero length, which means there's only one segment.
--the first output segment can have zero length too if `length` is zero.
local function segments(start, length, size)
	if length > 0 then
		local length1 = size + 1 - start
		return start, min(length, length1), 1, max(0, length - length1)
	else --negative length: map the input segment backwards from `start`
		local length1 = -start
		return start, max(length, length1), size, min(0, length - length1)
	end
end

local rb = {}

--stubs
function rb:_init() end
function rb:_read(start, length) end
function rb:_write(start, length, data, data_start) end

function rb:new(size, ...)
	local rb = {_size = size, _start = 1, _length = 0}
	setmetatable(rb, {__index = self})
	rb:_init(...)
	return rb
end

function rb:size() return self._size end
function rb:length() return self._length end
function rb:isfull() return self._length == self._size end
function rb:isempty() return self._length == 0 end

function rb:next_segment(i0)
	local i1, n1, i2, n2 = segments(self._start, self._length, self._size)
	if not i0 and n1 ~= 0 then --first segment, if any
		return i1, n1
	elseif i0 == i1 and n2 ~= 0 then --second segment, if any
		return i2, n2
	end
end

function rb:segments() --return iterator() -> start, length
	return rb.next_segment, self
end

--push data into the buffer, which triggers 1 or 2 writes.
function rb:push(data, length)
	length = length or 1
	assert(abs(length) <= self._size - self._length, 'buffer overflow')
	if length > 0 then
		local start = normalize(self._start + self._length, self._size)
		local i1, n1, i2, n2 = segments(start, length, self._size)
		self:_write(i1, n1, data, 1)
		self._length = self._length + n1
		if n2 ~= 0 then
			self:_write(i2, n2, data, 1 + n1)
			self._length = self._length + n2
		end
	else
		assert(false, 'invalid length') --can only push to tail
	end
end

--shift or pop data from the buffer, which triggers 1 or 2 reads.
function rb:shift(length)
	length = length or -1
	assert(abs(length) <= self._length, 'buffer underflow')
	if length > 0 then --remove from head
		local i1, n1, i2, n2 = segments(self._start, length, self._size)
		self:_read(i1, n1)
		self._start = normalize(i1 + n1, self._size)
		self._length = self._length - n1
		if n2 ~= 0 then
			self:_read(i2, n2)
			self._start = normalize(i2 + n2, self._size)
			self._length = self._length - n2
		end
	elseif length < 0 then --remove from tail
		local start = normalize(self._start + self._length - 1, self._size)
		local i1, n1, i2, n2 = segments(start, length, self._size)
		self:_read(i1, n1)
		self._length = self._length + n1 --n1 is negative
		if n2 ~= 0 then
			self:_read(i2, n2)
			self._length = self._length + n2 --n2 is negative
		end
	end
end

function rb:pop(length, ...)
	return self:shift(-length, ...)
end

--cdata buffer

local ffi

local cb = setmetatable({}, {__index = rb})

function cb:_init(ctype)
	ffi = ffi or require'ffi'
	local ctype = ffi.typeof(ctype or 'char')
	self._data = ffi.new(ffi.typeof('$[?]', ctype), self:size())
	self._ptype = ffi.typeof('$*', ctype)
end

function cb:_write(start, length, data, data_start)
	ffi.copy(
			ffi.cast(self._ptype, self._data) + start - 1,
			ffi.cast(self._ptype, data) + data_start - 1,
			length)
end

function cb:_readbytes(data, length) end --stub

function cb:_read(start)
	self._readbytes(ffi.cast(self._ptype, self._data) + start - 1, length)
end

--value buffer

local vb = setmetatable({}, {__index = rb})

function vb:_init()
	self._data = {}
end

function vb:_write(offset, length, data, data_offset)
	for i = 0, length-1, length > 0 and 1 or -1 do
		self._data[offset+i] = data[data_offset+i]
	end
end

function vb:_read(offset, length)
	local sign = length > 0 and 1 or -1
	for i = offset, offset + length - sign, sign do
		self._readvalue(self._data[i])
		self._data[i] = false --keep the TValues
	end
end

function vb:shift(length, readvalue)
	self._readvalue = readvalue
	rb.shift(self, length)
end

--unit test

if not ... then
	local ffi = require'ffi'
	local time = require'time'

	--test algorithm
	print(segments(1, 5, 10))
	print(segments(6, 5, 10))
	print(segments(1, 10, 10))
	print(segments(10, -5, 10))
	print(segments(6, -5, 10))
	print(segments(10, -10, 10))
	print(segments(6, 10, 10))  --right overflow
	print(segments(5, -10, 10)) --left overflow

	local b = rb:new(10)
	assert(b:size() == 10)
	function b:_write(...) print('write', ...) end
	function b:_read(...) print('read', ...) end
	local function _(i,j)
		assert(b._start == i)
		assert((b._start + b._length - 1) % b._size == j)
	end
	for i,n in b:segments() do
		assert(false) --should have no segments
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
end

return {
	buffer      = rb,
	cdatabuffer = cb,
	valuebuffer = vb,
}

