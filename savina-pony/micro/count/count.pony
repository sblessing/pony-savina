use "../../util"

class iso Count is AsyncActorBenchmark
  let _messages: U64

  new iso create(messages: U64) =>
    _messages = messages
  
  fun box apply(c: AsyncBenchmarkCompletion) =>
    Producer.increment(c, Counter, _messages)
  
  fun tag name(): String => "Count"

actor Counter
  var _count: U64 = 0

  be increment() =>
    _count = _count + 1

  be retrieve(sender: Producer) =>
    sender.result(_count)
  
actor Producer
  let _bench: AsyncBenchmarkCompletion
  let _messages: U64

  new increment(c: AsyncBenchmarkCompletion, counter: Counter, messages: U64) =>
    _bench = c
    _messages = messages
    
    var i: U64 = 0

    while i < _messages do
      counter.increment()
      i = i + 1
    end
    
    counter.retrieve(this)
  
  be result(result': U64) =>
    _bench.complete()

  

