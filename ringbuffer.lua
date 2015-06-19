
-- FIFO and LIFO ring buffer.
-- Written by Cosmin Apreutesei. Public Domain.

local min, max, abs = math.min, math.max, math.abs

local rb = {}

--stubs
function rb:_init() end
function rb:_read(offset, length) end
function rb:_write(offset, length, data, offset) end

function rb:new(size)
	local rb = {_size = size, _start = 1, _length = 0}
	setmetatable(rb, {__index = self})
	rb:_init()
	return rb
end

function rb:size() return self._size end
function rb:length() return self._length end
function rb:isfull() return self._length == self._size end
function rb:isempty() return self._length == 0 end

--normalize an index if it exceeds buffer size up to twice-1
local function normalize(i, size)
	return i > size and i - size or i
end

--given an (index, length) range, where length is positive and can't
--exceed the buffer size, return the two (index, length) ranges that map
--the input range to the buffer. the second range can have zero length.
local function ranges_poz(start, length, size)
	local length1 = size + 1 - start
	return start, min(length, length1), 1, max(0, length - length1)
end

--same as above but for negative lengths, which means counting backwards.
--the resulting ranges also have negative lengths.
local function ranges_neg(start, length, size)
	local length1 = -start
	return start, max(length, length1), size, min(0, length - length1)
end

--push data into the buffer, which triggers 1 or 2 writes.
function rb:push(data, length)
	length = length or 1
	assert(abs(length) <= self._size - self._length, 'buffer overflow')
	if length > 0 then
		local start = normalize(self._start + self._length, self._size)
		local i1, n1, i2, n2 = ranges_poz(start, length, self._size)
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

--unshift or pop data from the buffer, which triggers 1 or 2 reads.
function rb:unshift(length)
	length = length or -1
	assert(abs(length) <= self._length, 'buffer underflow')
	if length > 0 then --remove from head
		local i1, n1, i2, n2 = ranges_poz(self._start, length, self._size)
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
		local i1, n1, i2, n2 = ranges_neg(start, length, self._size)
		self:_read(i1, n1)
		self._length = self._length + n1 --n1 is negative
		if n2 ~= 0 then
			self:_read(i2, n2)
			self._length = self._length + n2 --n2 is negative
		end
	end
end

function rb:pop(length)
	return self:unshift(-length)
end

--unit test

if not ... then
	local ffi = require'ffi'
	local time = require'time'
	local b = rb:new(10)
	print(ranges_poz(1, 5, 10))
	print(ranges_poz(6, 5, 10))
	print(ranges_poz(1, 10, 10))
	print(ranges_neg(10, -5, 10))
	print(ranges_neg(6, -5, 10))
	print(ranges_neg(10, -10, 10))
	print(ranges_poz(6, 10, 10))  --right overflow
	print(ranges_neg(5, -10, 10)) --leftoverflow

	assert(b:size() == 10)
	function b:_write(...) print('write', ...) end
	function b:_read(...) print('read', ...) end
	b:push('', 3) --1,3
	b:push('', 5) --1,8
	b:unshift(4) --4,8
	b:push('', 6) --4,4 (overflow)
	b:unshift(2) --4,2
	b:unshift(4) --4,8 (underflow)
	assert(b:length(4))

	local rand = math.random
	local b = rb:new(100)
	b._data = ffi.new('char[?]', b:size())
	function b:_write(offset, length, data, data_offset)
		--print('write', offset, length, data, data_offset)
		ffi.copy(ffi.cast('char*', self._data) + offset - 1, ffi.cast('char*', data) + data_offset - 1, length)
	end
	function b:_read(offset, length)
		--
	end
	function rands(n)
		return string.char(rand(('A'):byte(), ('Z'):byte())):rep(n)
	end
	function b:print(...)
		local i1, n1, i2, n2 = ranges_poz(self._start, self._length, self._size)
		local s = ffi.string(self._data, self._size)
		if n2 == 0 then
			print((' '):rep(i1 - 1)..s:sub(i1, i1 + n1 - 1)..(' '):rep(self._size - n1 - i1 - 1), ...)
		else
			print(s:sub(1, n2)..(' '):rep(self._size - n1 - n2)..s:sub(i1, i1 + n1 - 1), ...)
		end
		--print(s:sub(i1, i1 + n1 - 1)..s:sub(i2, i2 + n2 - 1))
	end
	for i = 1, 200 do
		local n = math.floor(rand(-b:length(), b:size() - b:length())) / 3
		if n > 0 then
			b:push(rands(n), n)
		elseif n < 0 then
			b:pop(n * (rand() > .5 and 1 or -1))
		end
		print((' '):rep(b:size()))
		io.stdout:write'\x1b[1A' -- up one line
		b:print()
		io.stdout:write'\x1b[1A'
		time.sleep(0.02)
	end
	print()
end

return rb

