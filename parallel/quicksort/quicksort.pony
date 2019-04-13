use "cli"
use "collections"
use "../../util/"

primitive QuicksortConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("quicksort", "", [
        OptionSpec.u64(
          "dataset",
          "The data size. Defaults to 1000000."
          where short' = 'n', default' = 1000000
        )
        OptionSpec.u64(
          "max",
          "The maximum value. Defaults to 1L << 60."
          where short' = 'm', default' = U64(1 << 60)
        )
        OptionSpec.u64(
          "threshold",
          "Threshold to perfrom sort sequentially. Defaults to 2048."
          where short' = 't', default' = 2048
        )
        OptionSpec.u64(
          "seed",
          "The seed for the random number generator. Defaults to 1024."
          where short' = 's', default' = 1024
        )
      ]) ?
    end

actor Quicksort
  new run(args: Command val, env: Env) =>
    let length = args.option("dataset").u64()
    let seed = args.option("seed").u64()
    let max = args.option("max").u64()
    let threshold = args.option("threshold").u64()

    let list = recover List[U64] end
    let random = SimpleRand(seed)

    for i in Range[U64](0, length) do
      list.push((random.nextLong() % max).abs())
    end

    Sorter(None, PositionInitial, threshold, length).sort(consume list)

primitive PositionInitial
primitive PositionLeft
primitive PositionRight

type Position is 
  ( PositionInitial
  | PositionLeft
  | PositionRight
  )

actor Sorter
  let _parent: (Sorter | None)
  let _position: Position
  let _threshold: U64
  let _length: U64
  var _fragments: U64
  var _result: (List[U64] val | None)

  new create(parent: (Sorter | None), position: Position, threshold: U64, length: U64) =>
    _parent = parent
    _position = position
    _threshold = threshold
    _length = length
    _fragments = 0
    _result = None

  fun ref _validate(): Bool =>
    match _result
    | let data: List[U64] val =>
      if data.size() != _length.usize() then
        return false
      end
      
      try
        var current: U64 = data(0)?
        var next: USize = 1

        while next < _length.usize() do
          var loop_value = data(next)?

          if loop_value < current then
            return false
          end

          current = loop_value
          next = next + 1
        end
      else
        false
      end
    end

    true

  fun ref _pivotize(input: List[U64] val, pivot: U64): (List[U64] val, List[U64] val, List[U64] val) =>
    let l = recover List[U64] end
    let r = recover List[U64] end
    let p = recover List[U64] end

    for item in input.values() do
      if item < pivot then
        l.push(item)
      elseif item > pivot then
        r.push(item)
      else
        p.push(item)
      end
    end

    (consume l, consume r, consume p)

  fun ref _sort_sequentially(input: List[U64] val): List[U64] val ? =>
    let size = input.size()

    if size < 2 then
      return input
    end

    let pivot = input(size / 2)?
    let pivots = _pivotize(input, pivot)
    
    try
      let left_sorted = _sort_sequentially(pivots._1)?
      let right_sorted = _sort_sequentially(pivots._2)?

      recover 
        let sorted = List[U64] 
        sorted.concat(left_sorted.values())
        sorted.concat(pivots._3.values())
        sorted.concat(right_sorted.values())

        consume sorted
      end
    else
      error
    end

  fun ref _notify_parent() =>
    if _position is PositionInitial then
      @printf[I32]((" Result valid = " + _validate().string()).cstring())
    else
      match (_parent, _result)
      | (let parent: Sorter, let data: List[U64] val) => parent.result(data, _position)
      end
    end

  be sort(input: List[U64] val) =>
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

        Sorter(this, PositionLeft, _threshold, _length).sort(pivots._1)
        Sorter(this, PositionRight, _threshold, _length).sort(pivots._2)

        _result = pivots._3
        _fragments = _fragments + 1
      end
    end

  be result(sorted: List[U64] val, position: Position) => None
    if sorted.size() > 0 then
      _result = recover
        let temp = List[U64]

        match _result
        | let data: List[U64] val =>
          if _position is PositionLeft then
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

      _fragments = _fragments + 1

      if _fragments == 3 then
        _notify_parent()
      end
    end