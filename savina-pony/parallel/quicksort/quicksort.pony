use "collections"
use "../../util/"

class iso Quicksort is AsyncActorBenchmark
  let _dataset: U64
  let _max: U64
  let _threshold: U64
  let _seed: U64

  new iso create(dataset: U64, max: U64, threshold: U64, seed: U64) =>
    _dataset = dataset
    _seed = seed
    _max = max
    _threshold = threshold

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    let data = recover Array[U64] end
    let random = SimpleRand(_seed)

    for i in Range[U64](0, _dataset) do
      data.push(random.nextLong() % _max)
    end

    Sorter(c, None, PositionInitial, _threshold, _dataset).sort(consume data)

  fun tag name(): String => "Quicksort"

primitive PositionInitial
primitive PositionLeft
primitive PositionRight

type Position is 
  ( PositionInitial
  | PositionLeft
  | PositionRight
  )

actor Sorter
  let _bench: AsyncBenchmarkCompletion
  let _parent: (Sorter | None)
  let _position: Position
  let _threshold: U64
  let _length: U64
  var _fragments: U64
  var _result: (Array[U64] val | None)

  new create(c: AsyncBenchmarkCompletion, parent: (Sorter | None), position: Position, threshold: U64, length: U64) =>
    _bench = c
    _parent = parent
    _position = position
    _threshold = threshold
    _length = length
    _fragments = 0
    _result = None

  fun ref _pivotize(input: Array[U64] val, pivot: U64): (Array[U64] val, Array[U64] val, Array[U64] val) =>
    let l = recover Array[U64] end
    let r = recover Array[U64] end
    let p = recover Array[U64] end

    for item in input.values() do
      if item < pivot then
        l.push(item)
      elseif item > pivot then
        r.push(item)
      else
        p.push(item)
      end
    end

    (consume l, consume p, consume r)

  fun ref _sort_sequentially(input: Array[U64] val): Array[U64] val ? =>
    let size = input.size()

    if size < 2 then
      return input
    end

    let pivot = input(size / 2)?
    let pivots = _pivotize(input, pivot)
    
    try
      let left_sorted = _sort_sequentially(pivots._1)?
      let right_sorted = _sort_sequentially(pivots._3)?

      recover 
        let sorted = Array[U64](size)
        sorted.concat(left_sorted.values() where len = left_sorted.size())
        sorted.concat(pivots._2.values() where len = pivots._2.size())
        sorted.concat(right_sorted.values() where len = right_sorted.size())

        consume sorted
      end
    else
      error
    end

  fun ref _notify_parent() =>
    if _position is PositionInitial then
      _bench.complete()
    else
      match (_parent, _result)
      | (let parent: Sorter, let data: Array[U64] val) => parent.result(data, _position)
      end
    end

  be sort(input: Array[U64] val) =>
    let size = input.size()

    if size < _threshold.usize() then
      try
        _result = _sort_sequentially(input)?
        _notify_parent()
      end
    else
      try
        let pivot = input(size / 2)?
        let pivots = _pivotize(input, pivot)

        Sorter(_bench, this, PositionLeft, _threshold, _length).sort(pivots._1)
        Sorter(_bench, this, PositionRight, _threshold, _length).sort(pivots._3)

        _result = pivots._2
        _fragments = _fragments + 1
      end
    end

  be result(sorted: Array[U64] val, position: Position) => None
    if sorted.size() > 0 then
      _result = recover
        let temp = Array[U64]

        match _result
        | let data: Array[U64] val =>
          if position is PositionLeft then
            temp.concat(sorted.values())
            temp.concat(data.values())
          elseif position is PositionRight then
            temp.concat(data.values())
            temp.concat(sorted.values())
          end

          consume temp
        else
          None
        end
      end
    end

    _fragments = _fragments + 1

    if _fragments == 3 then
      _notify_parent()
    end