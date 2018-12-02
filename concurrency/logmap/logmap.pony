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

primitive NextMessage
primitive GetMessage
primitive UnknownTerm

type StashedMessage is 
  ( (NextMessage, (F64 | UnknownTerm))
  | (GetMessage, (F64 | UnknownTerm)) 
  )

class Stash
  var _master: LogmapMaster
  var _worker: SeriesWorker
  var _computer: RateComputer
 
  var _buffer: List[StashedMessage]

  new create(master: LogmapMaster, worker: SeriesWorker, computer: RateComputer) =>
    _master = master
    _worker = worker
    _computer = computer
    _buffer = List[StashedMessage]

  fun ref stash(message: StashedMessage) =>
    _buffer.push(message)

  fun ref populate(term: F64) =>
    // Find the leading pair of next and get messages
    // and populate the computed term, but if and only
    // if the term is unknown
    var found_next = false
    var found_get = false

    for stashed_message in _buffer.nodes() do
      try 
        let node = stashed_message()?

        match node
        | (NextMessage, UnknownTerm) => stashed_message.update((NextMessage, term))? ; found_next = true
        | (GetMessage, UnknownTerm) => stashed_message.update((GetMessage, term))? ; found_get = true
        end
      end

      if found_get and found_next then
        break
      end
    end

  fun ref unstash_all() =>
    var subsequent_stash = false

    for stashed_message in _buffer.nodes() do
      try
        let node = stashed_message()?

        if not subsequent_stash then
          match node
          | (NextMessage, let term: F64) => 
            _computer.compute(_worker, term) ; subsequent_stash = true   
          | (GetMessage, let computed_term: F64) => 
            _master.result(computed_term)
          end
        else
          _buffer.push(node) // Invariant: This node has an UnknownTerm
        end

        _buffer.shift()? 
      end
    end

actor SeriesWorker
  var _master: LogmapMaster
  var _computer: RateComputer
  var _term: F64
	var _stash: (Stash | None)

  new create(master: LogmapMaster, computer: RateComputer, term: F64) =>
    _master = master
    _computer = computer
    _term = term
    _stash = None

  be next() =>
    match _stash
    | let s: Stash => s.stash((NextMessage, UnknownTerm))
    else
      _computer.compute(this, _term)
      _stash = Stash(_master, this, _computer)
    end     

	be result(term: F64) =>
    _term = term

	  match _stash
    | let s: Stash => s.populate(_term) ; s.unstash_all() ; _stash = None
    end
	
  be get() =>
    match _stash
    | let s: Stash => s.stash((GetMessage, UnknownTerm))
    else
      _master.result(_term)
    end

actor RateComputer
  var _rate: F64

  new create(rate: F64) =>
    _rate = rate

  be compute(worker: SeriesWorker, term: F64) =>
    worker.result(_rate * term * (1 - term))