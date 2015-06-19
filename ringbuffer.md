---
tagline: FIFO/LIFO ring buffers
---

## `local rb = require'ringbuffer'`

FIFO/LIFO ring buffers.

## API

-------------------------------- --------------------------------------------------
__common__
bb:size() -> n                       buffer size
bb:length() -> n                     buffer occupied size
bb:isempty() -> true | false         check if empty
bb:isfull() -> true | false          check if full
bb:ranges() -> iter() -> i, len      range iterator returning (index, length)
__byte ring buffers__
rb.cdatabuffer(size[, ctype]) -> bb  create a cdata buffer (ctype = 'char')
bb:push(data, length)                add data to the tail of the buffer
bb:unshift(length, readbytes)        remove data from the head of the buffer
bb:pop(length, readbytes)            remove data from the tail of the buffer
__value ring buffers__
rb.valuebuffer(size) -> vb           create a buffer of arbitrary Lua values
vb:push(...)                         add values to the tail of the buffer
vb:unshift([count]) -> v1, ...       remove values from the head of the buffer
vb:pop([count]) -> v1, ...           remove values from the tail of the buffer
-------------------------------- --------------------------------------------------

> Note: remove() and unshift() are complementary: passing a negative
index to one results in the behavior of the other.

## Extending

The built-in ring buffers are based on the abstract class `rb.ringbuffer`.
The abstract ring buffer doesn't hold any data. Instead, it calls the
_read() and _write() methods for reading and writing from/into the buffer.
Each push/pop generates at most two reads/writes.

-------------------------------------------------- ---------------------------
setmetatable({}, {__index = rb.ringbuffer}) -> b   subclass the ringbuffer
b:_init()                                          constructor
b:_write(offset, length, data, data_offset)        called when adding data
b:_read(offset, length)                            called when removing data
--------------------------------------------------- --------------------------
