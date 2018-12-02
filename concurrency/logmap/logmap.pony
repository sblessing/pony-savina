use "cli"
use "collections"

use @printf[I32](fmt: Pointer[U8] tag, ...) 

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
  var _workers: Array[SeriesWorker]
  var _terms: U64
  var _requested: U64
  var _received: U64
  var _sum: F64
  var _env: Env

  new create(terms: U64, series: U64, rate: F64, increment: F64, env: Env) =>
    _workers = Array[SeriesWorker](series.usize())
    _terms = terms
    _requested = 0
    _received = 0
    _sum = 0
    _env = env

    for j in Range[U64](0, series) do
      let start_term = j.f64() * increment

      _workers.push(
        SeriesWorker(
          this,
          RateComputer(rate + start_term),
          start_term
        )
      )
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

primitive NextMessage
primitive GetMessage

type StashedMessage is 
  ( NextMessage
  | GetMessage 
  )

class Stash
  var _master: LogmapMaster
  var _worker: SeriesWorker
  var _computer: RateComputer
 
  var _buffer: Array[StashedMessage]

  new create(master: LogmapMaster, worker: SeriesWorker, computer: RateComputer) =>
    _master = master
    _worker = worker
    _computer = computer
    _buffer = Array[StashedMessage]

  fun ref stash(message: StashedMessage) =>
    _buffer.push(message)

  fun ref unstash(term: F64): Bool =>
    try
      while true do
        let message = _buffer.shift()?

        match message
        | NextMessage => 
          _computer.compute(_worker, term)
          break
        | GetMessage => 
          if _buffer.size() == 0 then 
            _master.result(term) 
          else 
            _buffer.push(message) 
          end
        end
      end

      true
    else
      false // The message will be handeled in non-stash mode
    end

actor SeriesWorker
  var _master: LogmapMaster
  var _computer: RateComputer
  var _term: F64
	var _stash: Stash
  var _stash_mode: Bool

  new create(master: LogmapMaster, computer: RateComputer, term: F64) =>
    _master = master
    _computer = computer
    _term = term
    _stash = Stash(_master, this, _computer)
    _stash_mode = false

  be next() =>
    if _stash_mode then
      _stash.stash(NextMessage)
    else
      _computer.compute(this, _term)
      _stash_mode = true
    end     

	be result(term: F64) =>
    _term = term

	  if _stash_mode then
      _stash_mode = _stash.unstash(_term)
    end
	
  be get() =>
    if _stash_mode then
      _stash.stash(GetMessage)
    else
      _master.result(_term)
    end

actor RateComputer
  let _rate: F64

  new create(rate: F64) =>
    _rate = rate

  be compute(worker: SeriesWorker, term: F64) =>
    worker.result(_rate * term * (1 - term))