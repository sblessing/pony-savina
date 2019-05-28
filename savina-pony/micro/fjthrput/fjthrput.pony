use "cli"
use "collections"
use "../../util"

/*primitive FjthrputConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("fjthrput", "", [
        OptionSpec.u64(
          "messages",
          "The total number of messages per actor Defaults to 10000."
          where short' = 'm', default' = 10000
        )
        OptionSpec.u64(
          "actors",
          "The total number of actors to be created. Defaults to 60."
          where short' = 'a', default' = 60
        )
        OptionSpec.u64(
          "channels",
          "The number of channels. Currently ignored. Defaults to 1."
          where short' = 'c', default' = 1
        )
        OptionSpec.bool(
          "priorities",
          "Use priorities. Currently ignored. Defaults to true."
          where short' = 'o', default' = true
        )
      ]) ?
    end*/

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
  
  fun box apply(c: AsyncBenchmarkCompletion) =>
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