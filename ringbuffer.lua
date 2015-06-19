
-- FIFO/LIFO Ring Buffers.
-- Written by Cosmin Apreutesei. Public Domain.

if not ... then require'ringbuffer_test'; return end

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

--callback-based buffer

local rb = {}
setmetatable(rb, rb)

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
rb.__call = rb.new

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

function rb:data() return self._data end --stub

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
	length = length or 1
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
	return self:shift(-(length or 1), ...)
end

function rb:peek(start)

end

--cdata buffer

local ffi --init at runtime for Lua5.1 compatiblity

local cb = setmetatable({}, {__index = rb, __call = rb.new})

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

function cb:_readdata(data, length) end --stub

function cb:_read(start)
	self._readdata(ffi.cast(self._ptype, self._data) + start - 1, length)
end

--value buffer

local vb = setmetatable({}, {__index = rb, __call = rb.new})

function vb:_init()
	self._data = {}
end

function vb:_write(start, length, data, data_start)
	self._data[start] = data
end

function vb:_read(start, length)
	self._val = self._data[start]
	self._data[start] = false --keep the TValue
end

function vb:push(val) --no length arg
	rb.push(self, val)
end

function vb:shift()
	rb.shift(self, 1)
	local val = self._val
	self._val = nil
	return val
end

function vb:pop()
	rb.shift(self, -1)
	local val = self._val
	self._val = nil
	return val
end

return {
	segments    = segments,
	buffer      = rb,
	cdatabuffer = cb,
	valuebuffer = vb,
}
