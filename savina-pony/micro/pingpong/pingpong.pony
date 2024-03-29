use "../../util"

class iso PingPong is AsyncActorBenchmark
  let _pings: U64

  new iso create(pings: U64) =>
    _pings = pings
  
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Ping(c, _pings, Pong)

  fun tag name(): String => "Ping Pong"

actor Ping
  let _bench: AsyncBenchmarkCompletion
  var _left: U64
  var _pong: Pong

  new create(c: AsyncBenchmarkCompletion, pings: U64, pong': Pong) =>
    _bench = c
    _left = pings - 1
    _pong = pong'
    _pong.ping(this)

  be pong() =>
    if _left > 0 then
      _pong.ping(this)
      _left = _left - 1
    else
      _bench.complete()
    end

actor Pong
  var _count: U64 = 0

  be ping(sender: Ping) =>
    sender.pong()
    _count = _count + 1
