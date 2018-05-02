use "cli"
use "collections"
use "random"

primitive BigConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("big", "", [
        OptionSpec.u64(
          "pings",
          "The number of pings sent by each actor. Defaults to 20000."
          where short' = 'p', default' = 20000
        )
        OptionSpec.u64(
          "actors",
          "The number of actors. Defaults to 120."
          where short' = 'a', default' = 120
        )
      ]) ?
    end

actor Big
  new run(args: Command val, env: Env) =>
    var pings = args.option("pings").u64()
    var actors = args.option("actors").u64()

    var n: Array[BigActor] iso = 
      recover Array[BigActor](actors.usize()) end
    
    for i in Range[I64](0, actors.i64()) do
      n.push(BigActor(i, pings))
    end

    var neighbors: Array[BigActor] val = consume n

    for big in neighbors.values() do
      big.neighbors(neighbors)
    end

    for big in neighbors.values() do
      big.pong(-1)
    end

actor BigActor
  let _index: I64
  var _pings: U64
  var _neighbors: Array[BigActor] val
  var _sent: U64
  
  new create(index: I64, pings: U64) =>
    _index = index
    _pings = pings
    _sent = 0
    _neighbors = recover Array[BigActor](0) end

  be neighbors(n: Array[BigActor] val) =>
    _neighbors = n

  be ping(sender: I64) =>
    try
      _neighbors(sender.usize())?.pong(_index)
    end
    
  be pong(n: I64) =>
    if _sent < _pings then
      try
        let target = _neighbors(Rand.int[USize](_neighbors.size())) ?
        target.ping(_index)
        _sent = _sent + 1
      end
    end