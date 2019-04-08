use "cli"
use "collections"
use "random"

primitive RadixsortConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("radixsort", "", [
        OptionSpec.u64(
          "dataset",
          "The data size. Defaults to 100000."
          where short' = 'n', default' = 100000
        )
        OptionSpec.u64(
          "max",
          "The maximum value. Defaults to 1L << 60."
          where short' = 'm', default' = U64(1 << 60)
        )
        OptionSpec.u64(
          "seed",
          "The seed for the random number generator. Defaults to 2048."
          where short' = 's', default' = 2048
        )
      ]) ?
    end

type Neighbor is (Validation | Sort)

actor Radixsort
  new run(args: Command val, env: Env) =>
    let size = args.option("dataset").u64()
    let max = args.option("max").u64()
    let seed = args.option("seed").u64()

    var radix = max / 2
    var next: Neighbor = Validation(size)

    while radix > 0:
      next = Sort(size, radix, next)
      radix = radix / 2
    end

    Source(size, max, seed, next)

actor Validation
  let _size: U64
  var _sum: F64
  var _received: U64
  var _previous: U64
  var _error: (I64, I32)

  new create(size: U64) =>
    _size = size
    _sum = 0
    _received = 0
    _previous = 0
    _error = (-1, -1)

  be value(n: U64) =>
    _received = _received + 1
    if n < _previous and _error._1 < 0 then
      _error = (n.i64(), (_received - 1).i64())
    end

    _previous = n
    _sum = _sum + _previous.f64()

    if _received == _size then
      _env.out.print("Elements sum: " + _sum.string())
    end

actor Source
  new create(size; U64, max: U64, seed: U64, next: Neighbor) =>
    let random = Rand(seed)

    for i in Range[U64](0, size) do
      next.value(random.next().abs() % max)
    end


actor Sort
  let _next: Neighbor
  let _size: U64
  var _data: Array[U64]
  var _received: U64
  var _current: U64

  new create(size: U64, radix: U64, next: Neighbor) =>
    _next = next
    _size = size
    _data = Array[U64](size.usize())
    _received = 0
    _current = 0

  be value(n: U64) =>
    _received = received + 1

    if (n and _radix) == 0 then
      _next.value(n)
    else
      try _data(_current)? = n end
      _current = _current + 1
    end

    if _received == _size then
      for i in Range[U64](0, _current) do
        try _next.value(_data(i)?) end
      end
    end