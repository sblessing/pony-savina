use "collections"
use "../../util"

type Neighbor is (Validation | Sorter)

class iso Radixsort is AsyncActorBenchmark
  let _dataset: U64
  let _max: U64
  let _seed: U64

  new iso create(dataset: U64, max: U64, seed: U64) =>
    _dataset = dataset
    _max = max
    _seed = seed

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    var radix = _max / 2
    var next: Neighbor = Validation(c, _dataset)

    while radix > 0 do
      next = Sorter(_dataset, radix, next)
      radix = radix / 2
    end

    Source(_dataset, _max, _seed, next)
  
  fun tag name(): String => "Radixsort"

actor Validation
  let _bench: AsyncBenchmarkCompletion
  let _size: U64
  var _sum: F64
  var _received: U64
  var _previous: U64
  var _error: (I64, I32)

  new create(c: AsyncBenchmarkCompletion, size: U64) =>
    _bench = c
    _size = size
    _sum = 0
    _received = 0
    _previous = 0
    _error = (-1, -1)

  be value(n: U64) =>
    _received = _received + 1
    if (n < _previous) and (_error._1 < 0) then
      _error = (n.i64(), (_received - 1).i32())
    end

    _previous = n
    _sum = _sum + _previous.f64()

    if _received == _size then
      _bench.complete()
    end

actor Source
  new create(size: U64, max: U64, seed: U64, next: Neighbor) =>
    let random = SimpleRand(seed)

    for i in Range[U64](0, size) do
      next.value(random.nextLong().abs() % max)
    end

actor Sorter
  let _next: Neighbor
  let _size: U64
  let _radix: U64
  var _data: Array[U64]
  var _received: U64
  var _current: U64

  new create(size: U64, radix: U64, next: Neighbor) =>
    _next = next
    _size = size
    _radix = radix
    _data = Array[U64].init(U64(0), size.usize())
    _received = 0
    _current = 0

  be value(n: U64) =>
    _received = _received + 1

    if (n and _radix) == 0 then
      _next.value(n)
    else
      try _data(_current.usize())? = n end
      _current = _current + 1
    end

    if _received == _size then
      for i in Range[USize](0, _current.usize()) do
        try _next.value(_data(i)?) end
      end
    end
