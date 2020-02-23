use "collections"
use "../../util"

class iso Concdict is AsyncActorBenchmark
  let _workers: U64
  let _messages: U64
  let _percentage: U64

  new iso create(workers: U64, messages: U64, percentage: U64) =>
    _workers = workers
    _messages = messages
    _percentage = percentage
  
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Master(
      c,
      _workers,
      _messages,
      _percentage
    )

  fun tag name(): String => "Concurrent Dictionary"

actor Master
  let _bench: AsyncBenchmarkCompletion
  var _workers: U64

  new create(c: AsyncBenchmarkCompletion, workers: U64, messages: U64, percentage: U64) =>
    _bench = c
    _workers = workers

    let dictionary = Dictionary

    for i in Range[U64](0, workers) do
      Worker(this, i,dictionary, messages, percentage).work()
    end
  
  be done() =>
    if (_workers = _workers - 1) == 1 then
      _bench.complete()
    end
    
actor Worker
  let _master: Master
  let _percentage: U64
  let _dictionary: Dictionary
  let _random: SimpleRand
  var _messages: U64

  new create(master: Master, index: U64, dictionary: Dictionary, messages: U64, percentage: U64) =>
    _master = master
    _percentage = percentage
    _dictionary = dictionary
    _random = SimpleRand(index + messages + percentage)
    _messages = messages

  be work(value: U64 = 0) =>
    if (_messages = _messages - 1) >= 1 then
      var value' = _random.nextInt(where max = 100).u64()
      value' = value' % (I64.max_value() / 4096).u64()

      if value' < _percentage then
        _dictionary.write(this, value', value')
      else
        _dictionary.read(this, value')
      end
    else
      _master.done()
    end  

actor Dictionary
  var _map: HashMap[U64, U64, HashEq[U64]]

  new create() =>
    _map = HashMap[U64, U64, HashEq[U64]](U32.max_value().usize() / 4096)

  be write(worker: Worker, key: U64, value: U64) =>
    _map(key) = value
    worker.work(value)

  be read(worker: Worker, key: U64) =>
    worker.work(try _map(key) ? else 0 end)