use "collections"
use "random"
use "../../util"

class iso BndBuffer is AsyncActorBenchmark
  let _buffersize: U64
  let _producers: U64
  let _consumers: U64
  let _items: U64
  let _producercosts: U64
  let _consumercosts: U64

  new iso create(buffersize: U64, producers: U64, consumers: U64, items: U64, producercosts: U64, consumercosts: U64) =>
    _buffersize = buffersize
    _producers = producers
    _consumers = consumers
    _items = items
    _producercosts = producercosts
    _consumercosts = consumercosts

  fun box apply(c: AsyncBenchmarkCompletion) => 
    Manager(
      c,
      _buffersize, 
      _producers,
      _consumers,
      _items,
      _producercosts,
      _consumercosts
    )

  fun tag name(): String => "Bounded Buffer" 

actor Manager
  let _bench: AsyncBenchmarkCompletion
  var _producer_count: U64
  var _producers: Array[Producer]
  var _consumers: Array[Consumer]
  var _availableProducers: List[Producer]
  var _availableConsumers: List[Consumer]
  var _pendingData: List[(Producer, F64)]
  var _adjusted: USize

  new create(c: AsyncBenchmarkCompletion, buffersize: U64, producers: U64, consumers: U64, items: U64, producercosts: U64, consumercosts: U64) =>
    _bench = c
    _producer_count = producers
    _producers = Array[Producer](producers.usize())
    _consumers = Array[Consumer](consumers.usize())
    _availableProducers = List[Producer]
    _availableConsumers = List[Consumer]
    _pendingData= List[(Producer, F64)]
    _adjusted = (buffersize - producers).usize()

    for i in Range[U64](0, producers) do
      _producers.push(Producer(this, items, producercosts))
    end
    
    for j in Range[U64](0, consumers) do
      let consumer = Consumer(this, consumercosts)

      _consumers.push(consumer)
      _availableConsumers.push(consumer)
    end

  fun ref _complete() =>
    if (_producer_count == 0) and (_availableConsumers.size() == _consumers.size()) then
      _bench.complete()
    end    

  be data(producer: Producer, item: F64) =>
    if _availableConsumers.size() == 0 then
      _pendingData.push((producer, item))
    else
      try
        _availableConsumers.shift()?.data(producer, item)
      end
    end

    if _pendingData.size() >= _adjusted then
      _availableProducers.push(producer)
    else
      producer.produce()
    end

  be available(consumer: Consumer) =>
    if _pendingData.size() == 0 then
      _availableConsumers.push(consumer)
      _complete()
    else
      try
        let item = _pendingData.shift()?
        consumer.data(item._1, item._2)

        if _availableProducers.size() > 0 then
          _availableProducers.shift()?.produce()          
        end
      end
    end
  
  be exit() => 
    _producer_count = _producer_count - 1
    _complete()

primitive ItemProcessor
  fun apply(current: F64, cost: U64): F64 =>
      var result = current
      let random = Rand(cost)

      if cost > 0 then
        for i in Range[U64](0, cost) do
          for j in Range[U64](0, 100) do
            result = result + (random.next().abs().f64() + 0.01).log()
          end
        end
      else
        result = result + (random.next().abs().f64() + 0.01).log()
      end

      result

actor Producer
  var _last: F64
  var _items: U64
  let _manager: Manager
  let _costs: U64

  new create(manager: Manager, items: U64, costs: U64) =>
    _last = 0
    _items = items
    _manager = manager
    _costs = costs
    _produce()

  fun ref _produce() =>
    if _items > 0 then
      _last = ItemProcessor(_last, _costs)
      _manager.data(this, _last)
      _items = _items - 1
    else
      _manager.exit()
    end
 
  be produce() => _produce()

actor Consumer
  var _last: F64
  let _manager: Manager
  let _costs: U64

  new create(manager: Manager, costs: U64) =>
    _last = 0
    _manager = manager
    _costs = costs

  be data(producer: Producer, item: F64) =>
    _last = ItemProcessor(_last + item, _costs)
    _manager.available(this)