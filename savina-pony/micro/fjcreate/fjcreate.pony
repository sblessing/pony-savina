use "cli"
use "collections"
use "../../util"

/*primitive FjcreateConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("fjcreate", "", [
        OptionSpec.u64(
          "workers",
          "The total number of actors to create. Defaults to 40000."
          where short' = 'w', default' = 40000
        )
      ]) ?
    end*/

primitive Token

class iso Fjcreate is AsyncActorBenchmark
  let _workers: U64

  new iso create(workers: U64) =>
    _workers = workers

  fun box apply(c: AsyncBenchmarkCompletion) =>
    ForkJoinMaster(c, _workers)
    
  fun tag name(): String => "Fork-Join Create"

actor ForkJoinMaster
  let _bench: AsyncBenchmarkCompletion
  var _workers: U64

  new create(c: AsyncBenchmarkCompletion, workers: U64) =>
    _bench = c
    _workers = workers

    for i in Range[U64](0, workers) do
      ForkJoin(this, Token)      
    end
  
  be done() =>
    if (_workers = _workers - 1) == 1 then
      _bench.complete()
    end

actor ForkJoin
  new create(master: ForkJoinMaster, token: Token) =>
    let n = F64(37.2).sin()
    let r = n * n

    master.done()

    