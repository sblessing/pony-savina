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

    Sorter(None, PositionInitial, threshold).sort(consume list)

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
  var _fragments: U64
  var _result: (List[U64] val | None)

  new create(parent: (Sorter | None), position: Position, threshold: U64) =>
    _parent = parent
    _position = position
    _threshold = threshold
    _fragments = 0
    _result = None

  fun ref _validate() =>
    None

  fun ref _sort_sequentially(input: List[U64] val): List[U64] val ? =>
    let size = input.size()

    if size < 2 then
      return input
    end

    let pivot = input(size / 2)?

    let left_unsorted = recover input.partition({ (n) => (n < pivot) })._1 end
    let right_unsorted = recover input.partition({ (n) => (n > pivot) })._2 end
    let pivots: List[U64] val = recover input.partition({ (n) => ( n == pivot )})._1 end

    try
      let left_sorted = _sort_sequentially(consume left_unsorted)?
      let right_sorted = _sort_sequentially(consume right_unsorted)?

      recover 
        let sorted = List[U64] 
        sorted.concat(left_sorted.values())
        sorted.concat(pivots.values())
        sorted.concat(right_sorted.values())

        consume sorted
      end
    else
      error
    end

  fun ref _notify_parent() =>
    if _position is PositionInitial then
      _validate()
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
        let left_unsorted = recover input.partition({ (n) => (n < pivot) })._1 end
        let right_unsorted = recover input.partition({ (n) => (n > pivot) })._2 end
        let pivots = recover input.partition({ (n) => ( n == pivot )})._1 end

        Sorter(this, PositionLeft, _threshold).sort(consume left_unsorted)
        Sorter(this, PositionRight, _threshold).sort(consume right_unsorted)

        _result = consume pivots
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