use "cli"
use "collections"
use "random"

primitive BndBufferConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("bndbuffer", "", [
        OptionSpec.u64(
          "buffersize",
          "The size of the buffer. Defaults to 6000."
          where short' = 'b', default' = 6000
        )
        OptionSpec.u64(
          "producers",
          "The number of producers. Defaults to 5000."
          where short' = 'p', default' = 5000
        )
        OptionSpec.u64(
          "consumers",
          "The number of consumers. Defaults to 2000."
          where short' = 'c', default' = 2000
        )
        OptionSpec.u64(
          "items",
          "The number of items per producer. Defaults to 1000."
          where short' = 'i', default' = 1000
        )
        OptionSpec.u64(
          "producercosts",
          "Producer costs. Defaults to 25."
          where short' = 'r', default' = 25
        )
        OptionSpec.u64(
          "consumercosts",
          "Consumer costs. Defaults to 25."
          where short' = 'o', default' = 25
        )
      ]) ?
    end

actor BndBuffer
  new run(args: Command val, env: Env) =>
    Manager(
      args.option("buffersize").u64(), 
      args.option("producers").u64(),
      args.option("consumers").u64(),
      args.option("items").u64(),
      args.option("producercosts").u64(),
      args.option("consumercosts").u64()
    )

actor Manager
  var _producers: Array[Producer]
  var _consumers: Array[Consumer]
  var _availableProducers: List[Producer]
  var _availableConsumers: List[Consumer]
  var _pendingData: List[(Producer, F64)]
  var _adjusted: USize

  new create(buffersize: U64, producers: U64, consumers: U64, items: U64, producercosts: U64, consumercosts: U64) =>
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
    else
      try
        let item = _pendingData.shift()?
        consumer.data(item._1, item._2)

        if _availableProducers.size() > 0 then
          _availableProducers.shift()?.produce()          
        end
      end
    end

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