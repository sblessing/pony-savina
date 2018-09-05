use "cli"
use "collections"

primitive PiprecisionConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("piprecision", "", [
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 20."
          where short' = 'w', default' = 20
        )
        OptionSpec.u64(
          "precision",
          "The scale (decimal places) to be computed. Defaults to 5000."
          where short' = 'p', default' = 5000
        )
      ]) ?
    end

primitive BbpTerm
  fun apply(scale: U64, term: U64): BigDecimal iso^ =>
    let k = 8 * term

    recover
      let result = BigDecimal.from(4)

      result.divide(BigDecimal.from(k + 1), scale, HalfEven)
      result - (BigDecimal.from(2).divide(BigDecimal.from(k + 4), scale, HalfEven))
      result - (BigDecimal.from(1).divide(BigDecimal.from(k + 5), scale, HalfEven))
      result - (BigDecimal.from(1).divide(BigDecimal.from(k + 6), scale, HalfEven))
      result.divide(BigDecimal.from(16).pow(k), scale, HalfEven)

      result
    end

actor Piprecision
  new run(args: Command val, env: Env) =>
    Master(
      args.option("workers").u64(),
      args.option("precision").u64()
    )

actor Master
  let _workers: Array[Worker]
  let _precision: U64
  let _tolerance: BigDecimal
  var _terms: U64
  var _result: BigDecimal
  
  new create(workers: U64, precision: U64) =>
    _workers = Array[Worker](workers.usize())
    _precision = precision
    _tolerance = BigDecimal.from[U64](1)
    _terms = 0
    _result = BigDecimal

    _tolerance.shift_left(precision)

    for i in Range[U64](0, workers) do
      _workers.push(Worker(i))
    end

    let threshold = U64(0)

    while threshold < _precision.min(10 * workers) do
      _continue(threshold % workers)
    end

   be result(value: BigDecimal iso, index: U64) =>
     _result = _result + recover ref consume value end

     if _result > _tolerance then
       _continue(index)
     end 

   fun ref _continue(index: U64) =>
     try 
       let worker = _workers(index.usize())?
       worker.work(this, _precision, _terms) 
       _terms = _terms + 1
     end

actor Worker
  let _index: U64

  new create(index: U64) =>
    _index = index

  be work(master: Master, precision: U64, term: U64) =>
    master.result(BbpTerm(precision, term), _index)