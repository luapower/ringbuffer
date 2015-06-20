
-- FIFO/LIFO Ring Buffers.
-- Written by Cosmin Apreutesei. Public Domain.

if not ... then require'ringbuffer_test'; return end

local assert, min, max, abs = assert, math.min, math.max, math.abs

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

--abstract buffer factory: provides the ring buffer logic only and relies
--on a constructor to provide the read() and write() functions for I/O.
local function bufferfactory(cons)
	return function(size)
		local start = 1
		local length = 0
		local read, write = cons(size)
		local rb = {}

		function rb:size() return size end
		function rb:length() return length end
		function rb:isfull() return length == size end
		function rb:isempty() return length == 0 end

		function rb:next_segment(i0)
			local i1, n1, i2, n2 = segments(start, length, size)
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
		function rb:push(data, len)
			len = len or 1
			assert(abs(len) <= size - length, 'buffer overflow')
			if len > 0 then
				local start = normalize(start + length, size)
				local i1, n1, i2, n2 = segments(start, len, size)
				write(i1, n1, data, 1)
				length = length + n1
				if n2 ~= 0 then
					write(i2, n2, data, 1 + n1)
					length = length + n2
				end
			else
				assert(false, 'invalid length') --can only push to tail
			end
		end

		--shift or pop data from the buffer, which triggers 0, 1 or 2 reads.
		function rb:shift(len)
			len = len or 1
			assert(abs(len) <= length, 'buffer underflow')
			if len > 0 then --remove from head
				local i1, n1, i2, n2 = segments(start, len, size)
				read(i1, n1)
				start = normalize(i1 + n1, size)
				length = length - n1
				if n2 ~= 0 then
					read(i2, n2)
					start = normalize(i2 + n2, size)
					length = length - n2
				end
			elseif len < 0 then --remove from tail
				local start = normalize(start + length - 1, size)
				local i1, n1, i2, n2 = segments(start, len, size)
				read(i1, n1)
				length = length + n1 --n1 is negative
				if n2 ~= 0 then
					read(i2, n2)
					length = length + n2 --n2 is negative
				end
			end
		end

		function rb:pop(len, ...)
			return rb:shift(-(len or 1), ...)
		end

		return rb
	end
end

--callback buffer: relies on self:_read() and self:_write() methods.
local function callbackbuffer(size)
	local b
	b = bufferfactory(function(size)
		local function read(...)
			return b:read(...)
		end
		local function write(...)
			return b:write(...)
		end
		return read, write
	end)(size)
	return b
end

local ffi --init on demand so that the module can be used without luajit

local function cdatabuffer(size, ctype, readdata)
	ffi = ffi or require'ffi'
	local copy, cast = ffi.copy, ffi.cast
	local ctype = ffi.typeof(ctype)
	local ptype = ffi.typeof('$*', ctype)
	local buf   = ffi.new(ffi.typeof('$[?]', ctype), size)
	local pbuf  = cast(ptype, buf)
	local b = bufferfactory(function(size)
		local function read(start, len)
			readdata(pbuf + (start - 1), len)
		end
		local function write(start, len, data, datastart)
			copy(pbuf + (start - 1), cast(ptype, data) + (datastart - 1), len)
		end
		return read, write
	end)(size)
	function b:data() return buf end --pin it!
	return b
end

local function valuebuffer(size)
	local val    --upvalue for data transfer
	local t = {} --the ring buffer is a simple array

	local b = bufferfactory(function(size)
		local function read(start)
			val = t[start]
			t[start] = false --keep the table slot occupied
		end
		local function write(start, _, data)
			t[start] = data
		end
		return read, write
	end)(size)

	--methods
	local bpush, bshift = b.push, b.shift
	function b:push(val) bpush(self, val) end
	local function shift(len)
		bshift(self, len)
		local v = val
		val = nil --unpin it
		return v
	end
	function b:shift() return shift(1) end
	function b:pop() return shift(-1) end
	function b:values() return t end

	return b
end

return {
	segments       = segments,
	bufferfactory  = bufferfactory,
	callbackbuffer = callbackbuffer,
	cdatabuffer    = cdatabuffer,
	valuebuffer    = valuebuffer,
}
