use "cli"
use "collections"

primitive SieveConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("sieve", "", [
        OptionSpec.u64(
          "size",
          "The input size. Defaults to 100000."
          where short' = 's', default' = 100000
        )
        OptionSpec.u64(
          "buffersize",
          "The buffer size at each sieve actor. Defaults to 1000."
          where short' = 'u', default' = 1000
        )
      ]) ?
    end

actor Sieve
  new run(args: Command val, env: Env) =>
    let filter = PrimeFilter(where size = args.option("buffersize").u64())
    let producer = NumberProducer(args.option("size").u64(), filter)

actor NumberProducer
  new create(size: U64, filter: PrimeFilter) =>
    var candidate: U64 = 3

    while candidate < size do
      filter.check(candidate)
      candidate = candidate + 2
    end

actor PrimeFilter
  let _size: U64
  var _available: U64
  var _next: (PrimeFilter | None)
  var _locals: Array[U64]

  new create(initial: U64 = 2, size: U64) =>
    _size = size
    _available = size
    _next = None
    _locals = Array[U64](size.usize())

    _locals.push(initial)

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

  fun ref _is_local(value: U64): Bool ? =>
    for i in Range[USize](0, _available.usize()) do
      if (value % _locals(i) ?) == 0 then
        return false
      end
    end  

    true

  fun ref _handle_prime(value: U64) =>
    if _available > 0 then
      _locals.push(value)
      _available = _available - 1
    else
      _next = PrimeFilter(value, _size)
    end
