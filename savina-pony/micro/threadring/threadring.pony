use "cli"
use "collections"
use "../../util"

primitive ThreadRingConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("threadring", "", [
        OptionSpec.u64(
          "actors",
          "The total number of actors to create. Defaults to 100."
          where short' = 'n', default' = 100
        )
        OptionSpec.u64(
          "pass",
          "Number of pass messages. Does not need to be divisible by N. Defaults to 100000."
          where short' = 'r', default' = 100000
        )
      ]) ?
    end

class iso ThreadRing is AsyncActorBenchmark
  let _actors: U64
  let _pass: U64

  new iso create(actors: U64, pass: U64) =>
    _actors = actors
    _pass = pass

  fun box apply(c: AsyncBenchmarkCompletion) =>
    let first = RingActor(c)
    var next = first

    for k in Range[U64](0, _actors - 1) do
      let current = RingActor.neighbor(c, next)
      next = current
    end

    first.next(next)

    if _pass > 0 then
      first.pass(_pass)
    end
  
  fun tag name(): String => "Thread Ring"
    
actor RingActor
  let _bench: AsyncBenchmarkCompletion
  var _next: (RingActor | None)

  new create(c: AsyncBenchmarkCompletion) =>
    _bench = c
    _next = None

  new neighbor(c: AsyncBenchmarkCompletion, next': RingActor) =>
    _bench = c
    _next = next'

  be next(neighbor': RingActor) =>
    _next = neighbor'

  be pass(left: U64) =>
    if left > 0 then
      match _next
      | let n: RingActor => n.pass(left - 1)
      end
    else
      _bench.complete()
    end
    