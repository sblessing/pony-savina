use "collections"
use "../../util"

class iso Sieve is AsyncActorBenchmark
  let _size: U64
  let _buffersize: U64

  new iso create(size: U64, buffersize: U64) =>
    _size = size
    _buffersize = buffersize
  
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    let filter = PrimeFilter(c where size = _buffersize)
    let producer = NumberProducer(_size, filter)
  
  fun tag name(): String => "Sieve of Eratosthenes"

actor NumberProducer
  new create(size: U64, filter: PrimeFilter) =>
    var candidate: U64 = 3

    while candidate < size do
      filter.check(candidate)
      candidate = candidate + 2
    end

    filter.done()

actor PrimeFilter
  let _bench: AsyncBenchmarkCompletion
  let _size: U64
  var _available: U64
  var _next: (PrimeFilter | None)
  var _locals: Array[U64]

  new create(c: AsyncBenchmarkCompletion, initial: U64 = 2, size: U64) =>
    _bench = c
    _size = size
    _available = 1
    _next = None
    _locals = Array[U64].init(0, size.usize())

    try _locals(0) ? = initial end

  fun ref _is_local(value: U64): Bool ? =>
    for i in Range[USize](0, _available.usize()) do
      if (value % _locals(i) ?) == 0 then
        return false
      end
    end  

    true

  fun ref _handle_prime(value: U64) =>
    if _available < _size then
      try _locals(_available.usize()) ? = value end
      _available = _available + 1
    else
      _next = PrimeFilter(_bench, value, _size)
    end

  be check(value: U64) =>
    try
      if _is_local(value) ? then
        match _next
        | let n: PrimeFilter =>
          n.check(value)
        else
          _handle_prime(value)
        end
      end
    end
  
  be done() =>
    match _next
    | let n: PrimeFilter => n.done()
    else
      _bench.complete()
    end

 
