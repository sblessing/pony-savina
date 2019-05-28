use "cli"
use "collections"
use "random"
use "time"
use "../../util"

/*primitive BigConfig
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
    end*/

class iso Big is AsyncActorBenchmark
  let _pings: U64
  let _actors: U64

  new iso create(pings: U64, actors: U64) =>
    _pings = pings
    _actors = actors

  fun box apply(c: AsyncBenchmarkCompletion) =>
    BigMaster(c, _pings, _actors)
  
  fun tag name(): String => "Big"

actor BigMaster
  let _bench: AsyncBenchmarkCompletion
  var _actors: U64

  new create(c: AsyncBenchmarkCompletion, pings: U64, actors: U64) =>
    _bench = c
    _actors = actors

    var n: Array[BigActor] iso = 
      recover Array[BigActor](actors.usize()) end
    
    for i in Range[I64](0, actors.i64()) do
      n.push(BigActor(this, i, pings))
    end

    var neighbors: Array[BigActor] val = consume n

    for big in neighbors.values() do
      big.neighbors(neighbors)
    end

    for big in neighbors.values() do
      big.pong(-1)
    end
  
  be done() =>
    if (_actors = _actors - 1) == 1 then
      _bench.complete()
    end

actor BigActor
  let _master: BigMaster
  let _index: I64
  let _random: SimpleRand
  var _pings: U64
  var _neighbors: Array[BigActor] val
  var _sent: U64
  
  new create(master: BigMaster, index: I64, pings: U64) =>
    _master = master
    _index = index
    _pings = pings
    _random = SimpleRand(index.u64())
    
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
			  let index = _random.nextInt(where max = _neighbors.size().u32()).usize()
        let target = _neighbors(index) ?
        target.ping(_index)
        _sent = _sent + 1
      end
    else
      _master.done()
    end