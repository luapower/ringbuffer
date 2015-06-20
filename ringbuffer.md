---
tagline: FIFO/LIFO Ring Buffers
---

## `local rb = require'ringbuffer'`

Fixed-size ring buffers that can be used as queues (FIFO) or stacks (LIFO)
and can hold different kinds of values:

  * cdata buffers which hold cdata values of the same type
  * value buffers which hold arbitrary Lua values
  * callback buffers for callback-based I/O

## API

---------------------------------------- ------------------------------------------------
__cdata buffers__
rb.cdatabuffer(size, ctype, read) -> db  create a buffer for specific cdata values
db:push(data[, len])                     add data to the tail of the buffer
db:shift([len])                          remove data from the head of the buffer
db:pop([len])                            remove data from the tail of the buffer
db:data() -> buf                         the buffer (use with segments())
__value buffers__
rb.valuebuffer(size) -> vb               create a buffer for arbitrary Lua values
vb:push(val)                             add a value to the tail of the buffer
vb:shift() -> val                        remove a value from the head of the buffer
vb:pop() -> val                          remove a value from the tail of the buffer
vb:values() -> t                         the buffer (use with segments())
__callback-based buffers__
rb.callbackbuffer(size) -> cb            create a callback buffer
cb:write(start, len, data, datastart)    callback: called when adding data
cb:read(start, len)                      callback: called when removing data
__common API__
b:size() -> n                            buffer size
b:length() -> n                          buffer occupied size
b:isempty() -> true | false              check if empty
b:isfull() -> true | false               check if full
b:segments() -> iter() -> start, len     segment iterator
---------------------------------------- ------------------------------------------------

## API Notes

  * `pop()` and `shift()` are complementary: passing a negative length
to pop() results in a shift() and viceversa.
  * ndices `start` and `datastart` count from 1.
  * the value buffer can be used with plain Lua (ffi is loaded on demand)

## CData buffers

Probably the most useful, cdata buffers keep an array of cdata values
of the same size. Pushing data writes it to the buffer. Removing data
adjusts the buffer's length and start index and results in multiple
calls to a supplied `read(ctype_ptr, len)` function.

## Value buffers

Value buffers hold arbitrary Lua values (nils included) in a table.
For simplicity, values can only be added and removed one by one.

## Callback-based buffers

Callback-based buffers rely on callbacks to do all the reading and writing.
They only provide the ring buffer logic and the API. Adding data results
in multiple calls to `self:write()`. Removing data results in multiple calls
to `self:read()`.
