use "cli"
use "collections"

primitive FilterbankConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("filterbank", "", [
        OptionSpec.u64(
          "columns",
          "The number of columns. Defaults to 16384."
          where short' = 'c', default' = 16384
        )
        OptionSpec.u64(
          "simulations",
          "The number of simulations. Defaults to 34816."
          where short' = 's', default' = 34816
        )
        OptionSpec.u64(
          "channels",
          "The number of channels. Defaults to 8."
          where short' = 'm', default' = 8
        )
        OptionSpec.u64(
          "sinkrate",
          "The sink print rate. Defauls to 100."
          where short' = 'r', default' = 100
        )
      ]) ?
    end

type Matrix is Array[Array[U64] val] val

actor Filterbank
  new run(args: Command val, env: Env) =>
    let simulations = args.option("simulations").u64() 
    let columns = args.option("columns").u64()
    let sinkrate = args.option("sinkrate").u64()
    let width = columns.usize()
    var channels = args.option("channels").u64()
    
    channels = U64(2).max(U64(channels).min(33))

    var h = recover Array[Array[U64] val] end
    var f = recover Array[Array[U64] val] end

    for i in Range[U64](0, channels) do
      var hI = recover Array[U64].init(U64(0), width) end
      var fI = recover Array[U64].init(U64(0), width) end

      for j in Range[USize](0, width) do
        let k = j.u64()
     
        try
          hI(j)? = (k * columns) + (k * channels) + i + k + i + 1 
          fI(j)? = (i * k) + ( i * i ) + i + k
        end
      end

      h.push(consume hI)
      f.push(consume fI)
    end

    let producer = Producer(simulations)
    let sink = Sink(sinkrate)
    let combine = Combine(sink)
    let integrator = Integrator(channels, combine)
    let branch = Branch(channels, columns, consume h, consume f, integrator)
    let source = Source(producer, branch)

    producer.next(source)

actor Producer
  let _simulations: U64
  var _sent: U64
  
  new create(simulations: U64) =>
    _simulations = simulations
    _sent = 0

  be next(source: Source) =>
    if _sent < _simulations then
      source.boot()
      _sent = _sent + 1
    end

actor Sink
  let _sinkrate: U64
  var _count: U64

  new create(sinkrate: U64) =>
    _sinkrate = sinkrate
    _count = 0

  be value(n: U64) =>
    _count = (_count + 1) % _sinkrate

actor Combine
  let _sink: Sink

  new create(sink: Sink) =>
    _sink = sink

  be collect(map: HashMap[U64, U64, HashEq[U64]] iso) =>
    let local: HashMap[U64, U64, HashEq[U64]] = consume map
    var sum: U64 = 0
    
    for item in local.values() do
      sum = sum + item
    end

    _sink.value(sum)

actor Integrator
  let _channels: U64
  let _combine: Combine
  let _data: Array[HashMap[U64, U64, HashEq[U64]] iso]

  new create(channels: U64, combine: Combine) =>
    _channels = channels
    _combine = combine
    _data = Array[HashMap[U64, U64, HashEq[U64]] iso]
  
  be value(id: U64, n: U64) =>
    var processed = false
    var size: USize = _data.size()
    var i: USize = 0

    try
      while i < size do
        if not _data(i)?.contains(id) then
          _data(i)?(id) = n
          processed = true
          i = size
        end

        i = i + 1
      end

      if not processed then
        let new_map = recover HashMap[U64, U64, HashEq[U64]] end
        new_map(id) = n
        _data.push(consume new_map)
      end

      if _data(0)?.size() == _channels.usize() then
        let first = _data.pop()?
        _combine.collect(consume first)
      end
    end

  
actor Branch
  let _channels: U64
  let _columns: U64
  let _h: Matrix
  let _f: Matrix
  let _integrator: Integrator
  let _banks: Array[Bank]

  new create(channels: U64, columns: U64, h: Matrix, f: Matrix, integrator: Integrator) =>
    _channels = channels
    _columns = columns
    _h = h
    _f = f
    _integrator = integrator

    _banks = Array[Bank]

    var index: USize = 0

    for i in Range[U64](0, _channels) do
      index = i.usize()

      try
        _banks.push(Bank(i, _columns, _h(index)?, _f(index)?, _integrator))
      end
    end

  be value(n: U64) =>
    for bank in _banks.values() do
      bank.value(n)
    end

actor Source
  let _producer: Producer
  let _branch: Branch
  let _max: U64
  var _current: U64

  new create(producer: Producer, branch: Branch) =>
    _producer = producer
    _branch = branch
    _max = 1000
    _current = 0

  be boot() =>
    _branch.value(_current)
    _current = (_current + 1) % _max
    _producer.next(this)

actor Bank
  let _entry: Delay

  new create(id: U64, columns: U64, h: Array[U64] val, f: Array[U64] val, integrator: Integrator) =>
    _entry = Delay(columns - 1, 
      FirFilter(columns, h, 
        SampleFilter(columns, 
          Delay(columns - 1, 
            FirFilter(columns, f, 
              TaggedForward(id, integrator))))))  
  
  be value(n: U64) =>
    _entry.value(n)

actor Delay
  let _length: U64
  let _filter: FirFilter
  let _state: Array[U64]
  var _placeholder: USize

  new create(length: U64, filter: FirFilter) =>
    _length = length
    _filter = filter
    _state = Array[U64].init(U64(0), _length.usize())
    _placeholder = 0

  be value(n: U64) =>
    try
      _filter.value(_state(_placeholder)?)
      _state(_placeholder)? = n
      _placeholder = ((_placeholder.u64() + 1) % _length).usize()
    end

actor FirFilter
  let _length: U64
  let _coefficients: Array[U64] val
  let _next: (SampleFilter | TaggedForward)

  var _data: Array[U64]
  var _index: USize
  var _is_full: Bool

  new create(length: U64, coefficients: Array[U64] val, next: (SampleFilter | TaggedForward)) =>
    _length = length
    _coefficients = coefficients
    _next = next

    _data = Array[U64].init(U64(0), _length.usize())
    _index = 0
    _is_full = false

  be value(n: U64) =>
    try
      _data(_index)? = n
      _index = _index + 1

      if _index == _length.usize() then
        _is_full = true
        _index = 0
      end
      
      if _is_full then
        var sum: U64 = 0
        var i: USize = 0

        while i < _length.usize() do
          sum = sum + (_data(i)? * _coefficients(_length.usize() - i - 1)?)
          i = i + 1
        end
      
        _next.value(sum)
      end
    end

actor SampleFilter
  let _rate: U64
  let _delay: Delay

  var _samples_received: U64

  new create(rate: U64, delay: Delay) =>
    _rate = rate
    _delay = delay
    _samples_received = 0

  be value(n: U64) =>
    if _samples_received == 0 then
      _delay.value(n)
    else
      _delay.value(0)
    end

    _samples_received = (_samples_received + 1) % _rate

actor TaggedForward
  let _id: U64
  let _integrator: Integrator

  new create(id: U64, integrator: Integrator) =>
    _id = id
    _integrator = integrator

  be value(n: U64) =>
    _integrator.value(_id, n)
  
