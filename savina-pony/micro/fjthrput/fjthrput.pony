use "collections"
use "../../util"

class iso Fjthrput is AsyncActorBenchmark
  let _messages: U64
  let _actors: U64
  let _channels: U64
  let _priorities: Bool

  new iso create(messages: U64, actors: U64, channels: U64, priorities: Bool) =>
    _messages = messages
    _actors = actors
    _channels = channels
    _priorities = priorities
  
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    FjthrMaster(c, _messages, _actors, _channels, _priorities)
  
  fun tag name(): String => "Fork-Join Throughput"

actor FjthrMaster
  let _bench: AsyncBenchmarkCompletion
  var _total: U64

  new create(c: AsyncBenchmarkCompletion, messages: U64, actors: U64, channels: U64, priorities: Bool) =>
    _bench = c
    _total = messages * actors

    let throughputs = Array[Throughput](actors.usize())

    for i in Range[U64](0, actors) do
      throughputs.push(Throughput(this))
    end

    for j in Range[U64](0, messages) do
      for k in throughputs.values() do
        k.compute()
      end
    end
  
  be done() =>
    if (_total = _total - 1) == 1 then
      _bench.complete()
    end

actor Throughput
  let _master: FjthrMaster

  new create(master: FjthrMaster) =>
    _master = master

  be compute() =>
    let n = F64(37.2).sin()
    let r = n * n

    _master.done()