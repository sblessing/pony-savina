use "cli"
use "collections"

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
          "Number of pass messages. Does not need to be divisible by N. Defaults to 100.000."
          where short' = 'r', default' = 100000
        )
      ]) ?
    end

actor ThreadRing
  var _actors: U64
  var _pass: U64

  new run(args: Command val, env: Env) =>
    _actors = args.option("actors").u64()
    _pass = args.option("pass").u64()

   setup_ring()
 
  fun setup_ring() =>
    let first = RingActor
    var next = first

    for k in Range[U64](0, _actors - 1) do
      let current = RingActor.neighbor(next)
      next = current
    end

    first.next(next)

    if _pass > 0 then
      first.pass(_pass)
    end
    
actor RingActor
  var _next: (RingActor|None)

  new create() =>
    _next = None

  new neighbor(next': RingActor) =>
    _next = next'

  be next(neighbor': RingActor) =>
    _next = neighbor'

  be pass(left: U64) =>
    if left > 0 then
      match _next
      | let n: RingActor => n.pass(left - 1)
      end
    end
    