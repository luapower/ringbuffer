
-- bidirectional ring buffers represented as (start, length, size) tuples.
-- Written by Cosmin Apreutesei. Public Domain.

if not ... then require'ringbuffer_test'; return end

local ffi --init on demand so that the module can be used without luajit
local assert, min, max, abs = assert, math.min, math.max, math.abs

--stateless ring buffer algorithm. counts from 1!

local function normalize(i, size) --normalize i over (1, size) range
	return (i - 1) % size + 1
end

--the heart of the algorithm: sweep an arbitrary arc over a circle, returning
--one or two of the normalized arcs that map the input arc to the circle.
--the buffer segment (start, length) is the arc in this model, and a buffer
--ring (1, size) is the circle. `start` will be normalized to (1, size).
--`length` can be positive or negative and can't exceed `size`. the second
--output segment will have zero length if there's only one segment.
--the first output segment will have zero length if input length is zero.
local function segments(start, length, size)
	start = normalize(start, size)
	assert(abs(length) <= size, 'invalid length')
	if length > 0 then
		local length1 = size + 1 - start
		return start, min(length, length1), 1, max(0, length - length1)
	else --zero or negative length: map the input segment backwards from `start`
		local length1 = -start
		return start, max(length, length1), size, min(0, length - length1)
	end
end

local function free_segments(start, length, size)
	return segments(start + length, (length > 0 and 1 or -1) * size - length, size)
end

local function offset(offset, start, length, size) --offset from head or tail+1
	return normalize(start + offset + (offset >= 0 and 0 or length), size)
end

local function push(len, start, length, size)
	assert(abs(len) <= size - length, 'buffer overflow')
	local newlength = length + abs(len)
	if len > 0 then --add len forwards from tail+1
		local i1, n1, i2, n2 = segments(start + length, len, size)
		return start, newlength, i1, n1, i2, n2
	elseif len < 0 then --add len backwards from head-1
		local i1, n1, i2, n2 = segments(start - 1, len, size)
		local newstart = normalize(start + len, size)
		return newstart, newlength, i1, n1, i2, n2
	else
		return start, length, 1, 0, 1, 0
	end
end

local function pull(len, start, length, size)
	assert(abs(len) <= length, 'buffer underflow')
	local newlength = length - abs(len)
	if len > 0 then --remove len from head
		local i1, n1, i2, n2 = segments(start, len, size)
		local newstart = normalize(start + len, size)
		return newstart, newlength, i1, n1, i2, n2
	elseif len < 0 then --remove len from tail
		local i1, n1, i2, n2 = segments(start + length - 1, len, size)
		return start, newlength, i1, n1, i2, n2
	else
		return start, length, 1, 0, 1, 0
	end
end

local function cdatabuffer(b) --ring buffer for uniform cdata values
	ffi = ffi or require'ffi'
	b = b or {}
	assert(b.size, 'size expected')
	assert(b.size >= 1, 'invalid size')
	assert(b.data or b.ctype, 'data or ctype expected')
	b.start = b.start or 0
	b.length = b.length or 0 --assume empty
	assert(b.length >= 0 and b.length <= b.size, 'invalid length')
	assert(not b.autogrow or b.alloc or b.ctype, 'need alloc or ctype for autogrow')
	b.alloc = b.alloc or function(self, size)
		return ffi.new(ffi.typeof('$[?]', ffi.typeof(b.ctype)), size)
	end
	b.data = b.data or b:alloc(b.size)
	b.write = b.write or function(self, len, dst, dofs, src, sofs)
		ffi.copy(dst + dofs, src + sofs, len)
	end
	b.read  = b.read  or function(self, len, dst, dofs, src, sofs)
		ffi.copy(dst + dofs, src + sofs, len)
	end

	local function normalize_segs(i1, n1, i2, n2)
		if n1 < 0 then --invert direction of negative-size segments
			i1, n1 = i1 + n1 + 1, -n1
			i2, n2 = i2 + n2 + 1, -n2
		end
		return i1 - 1, n1, i2 - 1, n2 --count from 0
	end

	function b:checksize(len)
		if len <= b.size - b.length then return end
		local newsize = max(b.size * 2, b.length + len)
		local newdata = b:alloc(newsize)
		local i1, n1, i2, n2 = normalize_segs(segments(b.start + 1, b.length, b.size))
		ffi.copy(newdata,      b.data + i1, n1)
		ffi.copy(newdata + n1, b.data + i2, n2)
		b.data, b.size, b.start = newdata, newsize, 0
	end

	function b:push(src, len)
		len = len or 1
		if b.autogrow then
			b:checksize(len)
		end
		local start, length, i1, n1, i2, n2 = push(len, b.start + 1, b.length, b.size)
		b.start, b.length = start - 1, length --count from 0
		i1, n1, i2, n2 = normalize_segs(i1, n1, i2, n2)
		if n1 ~= 0 then b:write(n1, b.data, i1, src,  0) end
		if n2 ~= 0 then b:write(n2, b.data, i2, src, n1) end
		return i1, n1, i2, n2
	end

	function b:pull(dst, len, keep)
		len = len or 1
		local start, length, i1, n1, i2, n2 = pull(len, b.start + 1, b.length, b.size)
		if keep ~= 'keep' then
			b.start, b.length = start - 1, length --count from 0
		end
		i1, n1, i2, n2 = normalize_segs(i1, n1, i2, n2)
		if n1 ~= 0 then b:read(n1, dst,  0, b.data, i1) end
		if n2 ~= 0 then b:read(n2, dst, n1, b.data, i2) end
		return i1, n1, i2, n2
	end

	function b:offset(ofs)
		return offset(ofs or 0, b.start + 1, b.length, b.size) - 1
	end

	return b
end

local function valuebuffer(b) --ring buffer for arbitrary Lua values
	b = b or {}
	b.data = b.data or {}
	b.start = b.start or 1
	b.length = b.length or 0 --assume empty
	assert(b.size, 'size expected')
	assert(b.size >= 1, 'invalid size')
	assert(b.length >= 0 and b.length <= b.size, 'invalid length')

	local function checksign(sign)
		sign = sign or 1
		assert(abs(sign) == 1, 'invalid sign')
		return sign
	end

	function b:checksize(len)
		if len <= b.size - b.length then return end
		local newsize = max(b.size * 2, b.length + len)
		local i1, n1, i2, n2 = segments(b.start, b.length, b.size)
		if n1 > n2 then --move segment 2 right after segment 1
			local o = i1 + n1 - 1
			for i = 1, n2 do
				b.data[o + i] = b.data[i]
				b.data[i] = false --keep the slot
			end
		else --move segment 1 to the end of the new buffer
			local o = newsize - n1 + 1
			for i = 0, n1-1 do
				b.data[o + i] = b.data[i1 + i]
				b.data[i1 + i] = false --keep the slot
			end
			b.start = o
		end
		b.size = newsize
	end

	function b:push(val, sign)
		sign = checksign(sign)
		if b.autogrow then
			b:checksize(1)
		end
		local i
		b.start, b.length, i = push(sign, b.start, b.length, b.size)
		b.data[i] = val
		return i
	end

	function b:pull(sign, keep)
		sign = checksign(sign)
		local start, length, i = pull(sign, b.start, b.length, b.size)
		local val = b.data[i]
		if keep ~= 'keep' then
			b.start, b.length = start, length
			b.data[i] = false --remove the value but keep the slot
		end
		return val, i
	end

	function b:offset(ofs)
		return offset(ofs or 0, b.start, b.length, b.size)
	end

	return b
end

return {
	--algorithm
	segments = segments,
	free_segments = free_segments,
	offset   = offset,
	push     = push,
	pull     = pull,
	--buffers
	cdatabuffer = cdatabuffer,
	valuebuffer = valuebuffer,
}
