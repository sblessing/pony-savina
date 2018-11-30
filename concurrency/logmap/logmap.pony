use "cli"
use "collections"

primitive LogmapConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("logmap", "", [
        OptionSpec.u64(
          "terms",
          "The number of terms. Defaults to 25000."
          where short' = 't', default' = 25000
        )
        OptionSpec.u64(
          "series",
          "The number of series. Defaults to 10."
          where short' = 's', default' = 10
        )
        OptionSpec.f64(
          "rate",
          "The start rate. Defaults to 3.46."
          where short' = 'r', default' = 3.46
        )
        OptionSpec.f64(
          "increment",
          "The increment. Defaults to 0.0025."
          where short' = 'p', default' = 0.0025
        )
      ]) ?
    end

actor Logmap
  new run(args: Command val, env: Env) =>
    LogmapMaster(
      args.option("terms").u64(),
      args.option("series").u64(),
      args.option("rate").f64(),
      args.option("increment").f64(),
      env
    ).start()

actor LogmapMaster
  var _computers: Array[RateComputer]
  var _workers: Array[SeriesWorker]
  var _terms: U64
  var _requested: U64
  var _received: U64
  var _sum: F64
  var _env: Env

  new create(terms: U64, series: U64, rate: F64, increment: F64, env: Env) =>
    _computers = Array[RateComputer](series.usize())
    _workers = Array[SeriesWorker](series.usize())
    _terms = terms
    _requested = 0
    _received = 0
    _sum = 0
    _env = env

    for i in Range[U64](0, series) do
      _computers.push(RateComputer(rate + (i.f64() * increment)))
    end

    for j in Range[U64](0, series) do
      try 
        _workers.push(
          SeriesWorker(
            this,
            _computers((j % series).usize()) ?,
            j.f64() * increment
          )
        )
      end
    end
  
  be start() =>
    try
      for i in Range[U64](0, _terms) do
        for j in Range[USize](0, _workers.size()) do
          _workers(j)?.next()
        end
      end

			for k in Range[USize](0, _workers.size()) do
        _workers(k)?.get()
        _requested = _requested + 1
      end
    end
  
  be result(term: F64) =>
    _sum = _sum + term
    _received = _received + 1

    if _received == _requested then
      _env.out.print("Terms sum: " + _sum.string())
    end

actor SeriesWorker
  var _master: LogmapMaster
  var _computer: RateComputer
  var _term: F64
	var _stashes: List[F64]
	var _unfulfilled_gets: U64

  new create(master: LogmapMaster, computer: RateComputer, term: F64) =>
    _master = master
    _computer = computer
    _term = term
    _stashes = List[F64]
		_unfulfilled_gets = 0

  be next() =>
    _computer.compute(this, _term) 

	be result(term: F64) =>
	  _term = term

		if _unfulfilled_gets > 0 then
		  _unfulfilled_gets = _unfulfilled_gets - 1
			_master.result(_term)
		else
		  _stashes.push(_term)
		end 
	
  be get() =>
    try
		  _master.result(_stashes.shift()?) 
		else
		  _unfulfilled_gets = _unfulfilled_gets + 1
		end

actor RateComputer
  var _rate: F64

  new create(rate: F64) =>
    _rate = rate

  be compute(worker: SeriesWorker, term: F64) =>
    worker.result(_rate * term * (1 - term))
    