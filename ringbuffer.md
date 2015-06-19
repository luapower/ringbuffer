---
tagline: FIFO/LIFO Ring Buffers
---

## `local rb = require'ringbuffer'`

Fixed-size ring buffers that can be used as queues (FIFO) or stacks (LIFO)
and can hold different kinds of values:

  * cdata buffers for fixed-size cdata values
  * value buffers for arbitrary Lua values
  * callback-based buffers for extending and customizing

## API

------------------------------------- ------------------------------------------------
__cdata buffers__
rb.cdatabuffer(size[, ctype]) -> cb   create a cdata buffer (default ctype is 'char')
cb:push(data[, len])                  add data to the tail of the buffer
cb:shift([len])                       remove data from the head of the buffer
cb:pop([len])                         remove data from the tail of the buffer
cb:_readdata(ptr, len)                called when removing data
__value buffers__
rb.valuebuffer(size) -> vb            create a buffer of arbitrary Lua values
vb:push(val)                          add a value to the tail of the buffer
vb:shift() -> val                     remove a value from the head of the buffer
vb:pop() -> val                       remove a value from the tail of the buffer
__callback-based buffers__
rb.buffer:new(size) -> b              create a buffer
b:_init()                             constructor
b:_write(start, len, data, dstart)    called when adding data
b:_read(start, len)                   called when removing data
__common API__
b:size() -> n                         buffer size
b:length() -> n                       buffer occupied size
b:isempty() -> true | false           check if empty
b:isfull() -> true | false            check if full
b:segments() -> iter() -> start, len  segment iterator
b:data() -> buf                       data buffer (Lua table, cdata array, etc.)
------------------------------------- ------------------------------------------------

__Note:__ pop() and shift() are complementary: passing a negative count
to one results in the behavior of the other.

### Callback-based buffers

Callback-based buffers rely on callbacks to do all the memory allocation,
reading and writing. They only provide the ring buffer mechanism and the API.
Adding data results in multiple calls to _write(). Removing data results in
multiple calls to _read(). Indices start at 1.

### CData buffers

Probably the most useful, cdata buffers keep an array of cdata values.
Writing data writes to the buffer. Removing data results in multiple calls
to _readbytes().

### Value buffers

Value buffers hold arbitrary Lua values in a fixed-size table.
