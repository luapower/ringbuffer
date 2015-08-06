---
tagline: bidirectional ring buffers
---

## `local rb = require'ringbuffer2'`

The ring buffer algorithm is provided as an API operating on an abstract
buffer state defined as the tuple `(start, length, size)` where `start` is
in the `[1, size]` interval and `length` is in the `[0, size]` interval.
Two actual data structures are implemented with this API:

  * a cdata array buffer, which supports adding/removing elements in bulk.
  * a Lua array buffer, which can hold arbitrary Lua values.

For both kinds of buffers:

  * elements can be added/removed at both ends of the buffer (LIFO/FIFO).
  * the buffer can be fixed-size or auto-growing.
  * can work with an external, pre-allocated buffer.

__NOTE:__ This module can be used with plain Lua but cdatabuffer won't work.

## API

-------------------------------------------------------------- -----------------------------------------------------
__algorithm__
`rb.segments(start, length, size) -> segs...`                  buffer's occupied segments
`rb.free_segments(start, length, size) -> segs...`             buffer's free segments
`rb.offset(ofs, start, length, size) -> i`                     index at offset from head (or tail+1 if ofs < 0)
`rb.push(len, start, length, size) -> start, length, segs...`  push len elements to tail (or head if len < 0)
`rb.pull(len, start, length, size) -> start, length, segs...`  pull len elements from head (or tail if len < 0)
__cdata buffers__
`rb.cdatabuffer(db) -> db`                                     create a buffer for specific cdata values
`db:push(src[, len]) -> segs...`                               add data to tail (or head if len < 0)
`db:pull(dst[, len][, 'keep']) -> segs...`                     remove data from head (or tail if len < 0)
`db:checksize(len)`                                            grow the buffer to fit at least `len` more elements
`db:offset([ofs]) -> i`                                        offset from head (or from tail+1 if ofs < 0)
`db.data -> cdata`                                             the buffer itself
`db:alloc(len) -> cdata`                                       allocator (defaults to ffi.new)
`db:read(len, dst, dofs, src, sofs)`                           segment reader (defaults to ffi.copy)
`db:write(len, dst, dofs, src, sofs)`                          segment writer (defaults to ffi.copy)
__value buffers__
`rb.valuebuffer(vb) -> vb`                                     create a buffer for arbitrary Lua values
`vb:push(val[, sign]) -> i`                                    add value to tail (or head if sign = -1)
`vb:pull([sign][, 'keep']) -> val, i`                          remove value from head (or tail if sign = -1)
`vb:checksize(len)`                                            grow the buffer to fit at least `len` more elements
`vb:offset([ofs]) -> i`                                        get index at head+ofs (or tail+1+ofs if ofs < 0)
`vb.data -> t`                                                 the buffer itself
__buffer state__
`b.start -> i`                                                 start index
`b.size -> n`                                                  buffer size
`b.length -> n`                                                buffer occupied size
`b.autogrow -> true | false`                                   enable auto-growing when running out of space
-------------------------------------------------------------- -----------------------------------------------------

__API Notes:__

  * `segs...` means `index1, length1, index2, length2`;
  length2 can be 0 when the result is only one segment;
  length1 can be 0 only when the input length is 0.
  * algorithm indices start at 1.
  * valuebuffer indices start at 1.
  * cdatabuffer indices start at 0.
  * 'keep' means read but don't remove the data.

## CData buffers

CData buffers manage a cdata array. Pushing and pulling data results
in multiple calls to write() and read() respectively.

### `rb.cdatabuffer(db) -> db`

  * db is a table providing:
    * `size`: the size of the buffer.
    * `data` or `ctype`: the pre-allocated buffer, or the element type
    in which case a ctype[size] buffer will be allocated.
    * `start`, `length`: optional, if the buffer comes pre-filled.
    * `alloc`: optional custom allocator, for initial allocation and auto-growing.
    * `autogrow`: enable auto-growing.

## Value buffers

Value buffers hold arbitrary Lua values (nils included) in a table.
For simplicity, values can only be added and removed one by one.

### `rb.valuebuffer(vb) -> vb`

  * vb is a table providing:
    * `size`: the size of the buffer.
    * `data`, `start`, `length`: optional, if the buffer comes pre-filled.
    * `autogrow`: enable auto-growing.
