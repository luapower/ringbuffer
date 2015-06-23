---
tagline: ring buffers
---

## `local rb = require'ringbuffer'`

The ring buffer algorithm is provided as an API operating on an abstract
buffer state defined as the tuple `(start, length, size)` where start is
in `[1, size]` interval and length is in `[0, size]` interval. Two actual
data structures are implemented with this API:

  * a cdata array buffer, which supports adding/removing elements in bulk.
  * a Lua array buffer, which can hold arbitrary Lua values.

For both kinds of buffers:

  * elements can be added/removed at both ends of the buffer.
  * the buffer can be fixed-size or auto-growing.
  * can work with an external, pre-allocated buffer.

__NOTE:__ This module can be used with plain Lua but cdatabuffer won't work.

## API

-------------------------------------------- -----------------------------------------------------
__algorithm__
rb.segments(start, length, size) \           buffer segments (n2 can be 0) \
	-> i1, n1, i2, n2
rb.head(ofs, start, length, size) -> i       index at offset from head
rb.tail(ofs, start, length, size) -> i       index at offset from tail+1
rb.offset(ofs, start, length, size) -> i     index at offset from head (ofs > 0) or tail+1 (ofs < 0)
rb.push(len, start, length, size) \          push len elements to tail (or head) \
	-> newstart, newlength, i1, n1, i2, n2
rb.pull(len, start, length, size) \          pull len elements from head (or tail) \
	-> newstart, newlength, i1, n1, i2, n2
__cdata buffers__
rb.cdatabuffer(db) -> db                     create a buffer for specific cdata values
db:push(data[, len]) -> i1, n1, i2, n2       add data to tail (or head if len < 0)
db:pull([len][, 'keep']) -> i1, n1, i2, n2   remove data from head (or tail if len < 0)
db:read(ptr, len)                            callback for reading segments
db:offset([ofs]) -> i                        get index at head+ofs (or tail+1+ofs if ofs < 0)
db.data -> cdata                             the buffer itself
db:alloc(len) -> cdata                       optional custom allocator
db:checksize(len)                            grow the buffer to fit at least `len` more elements
__value buffers__
rb.valuebuffer(vb) -> vb                     create a buffer for arbitrary Lua values
vb:push(val[, sign]) -> i                    add value to tail (or head if sign = -1)
vb:pull([sign][, 'keep']) -> val, i          remove value from head (or tail if sign = -1)
vb:offset([ofs]) -> i                        get index at head+ofs (or tail+1+ofs if ofs < 0)
vb.data -> t                                 the buffer itself
vb:checksize(len)                            grow the buffer to fit at least `len` more elements
__buffer state__
b.start -> i                                 start index
b.size -> n                                  buffer size
b.length -> n                                buffer occupied size
b.autogrow -> true | false                   enable auto-growing when running out of space
-------------------------------------------- -----------------------------------------------------

__NOTE:__ valuebuffer indices start at 1; cdatabuffer indices start at 0.

## CData buffers

CData buffers manage a cdata array. Pushing data writes it to the buffer.
Removing data adjusts the buffer's length and start index and results
in multiple calls to a supplied `read(ptr, len)` callback.

### `rb.cdatabuffer(db) -> db`

  * db is a table providing:
    * `size`: the size of the buffer.
    * `data` or `ctype`: the pre-allocated buffer, or the element type
    in which case a ctype[size] buffer will be allocated.
    * `start`, `length`: optional, if the buffer comes pre-filled.
    * `alloc`: optional custom allocator, for initial allocation and auto-growing.
    * `autogrow`: enable auto-growing.

__NOTE:__ When reading data from the tail of the buffer, the read function
is called with the last segment first and then with the first segment.

## Value buffers

Value buffers hold arbitrary Lua values (nils included) in a table.
For simplicity, values can only be added and removed one by one.

### `rb.valuebuffer(vb) -> vb`

  * vb is a table providing:
    * `size`: the size of the buffer.
    * `data`, `start`, `length`: optional, if the buffer comes pre-filled.
    * `autogrow`: enable auto-growing.
