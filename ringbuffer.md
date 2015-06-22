---
tagline: ring buffers
---

## `local rb = require'ringbuffer'`

Fixed-size ring buffer algorithm and data structures.
Elements can be added to and removed from both ends of the buffer in bulk.
The buffer can be used as a stack or a queue or both at the same time.

The ring buffer algorithm is provided as an API operating on an abstract
buffer state defined as the tuple `(start, length, size)`. Two actual data
structures are implemented with this API:

  * a ring buffer which holds cdata values of the same type
  * a ring buffer which holds arbitrary Lua values

## API

-------------------------------------------- -----------------------------------------------------
__algorithm__
rb.segments(start, length, size) -> \        buffer segments (only one segment if n2 is 0)
	i1, n1, i2, n2
rb.head(ofs, start, length, size) -> i       index at offset from head
rb.tail(ofs, start, length, size) -> i       index at offset from tail+1
rb.offset(ofs, start, length, size) -> i     index at offset from head (ofs > 0) or tail+1 (ofs < 0)
rb.push(len, start, length, size) -> \       push len elements to tail (or head)
	newstart, newlength, i1, n1, i2, n2
rb.pull(len, start, length, size) -> \       pull len elements from head (or tail)
	newstart, newlength, i1, n1, i2, n2
__cdata buffers__
rb.cdatabuffer([db]) -> db                   create a buffer for specific cdata values
db:push(data[, len]) -> i1, n1, i2, n2       add data to tail (or head if len < 0)
db:pull([len][, 'keep']) -> i1, n1, i2, n2   remove data from head (or tail if len < 0)
db:read(ptr, len)                            callback for reading segments
db:offset([ofs]) -> i                        get index at head+ofs (or tail+1+ofs if ofs < 0)
db.data -> cdata                             the buffer itself
__value buffers__
rb.valuebuffer([vb]) -> vb                   create a buffer for arbitrary Lua values
vb:push(val[, sign]) -> i                    add value to tail (or head if sign = -1)
vb:pull([sign][, 'keep']) -> val, i          remove value from head (or tail if sign = -1)
vb:offset([ofs]) -> i                        get index at head+ofs (or tail+1+ofs if ofs < 0)
vb.data -> t                                 the buffer itself
__common API__
b.start -> i                                 start index
b.size -> n                                  buffer size
b.length -> n                                buffer occupied size
-------------------------------------------- -----------------------------------------------------

## API Notes

  * valuebuffer indices start at 1; cdatabuffer indices start at 0.
  * this module can also be used with plain Lua (ffi is loaded on demand).

## CData buffers

CDdata buffers keep an array of cdata values of the same type.
Pushing data writes it to the buffer. Removing data adjusts the
buffer's length and start index and results in multiple calls
to a supplied `read(ptr, len)` callback.

__NOTE:__ When reading data from the tail of the buffer, the read function
is called with the last segment first and then with the first segment.

## Value buffers

Value buffers hold arbitrary Lua values (nils included) in a table.
For simplicity, values can only be added and removed one by one.

## Callback-based buffers

Callback-based buffers rely on callbacks to do all the reading and writing.
They only provide the ring buffer logic and the API. Adding data results
in multiple calls to `self:write()`. Removing data results in multiple calls
to `self:read()`.
