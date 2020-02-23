use "collections"
use "../../util"

class iso Cigsmok is AsyncActorBenchmark
  let _rounds: U64
  let _smokers: U64

  new iso create(rounds: U64, smokers: U64) =>
    _rounds = rounds
    _smokers = smokers

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Arbiter(c, _rounds, _smokers)

  fun tag name(): String => "Cigarette Smokers"

actor Arbiter
  let _bench: AsyncBenchmarkCompletion
  let _random: SimpleRand
  var _smokers: Array[Smoker]
  var _rounds: U64

  new create(c: AsyncBenchmarkCompletion, rounds: U64, smokers: U64) =>
    _bench = c
    _random = SimpleRand(rounds * smokers)
    _smokers = Array[Smoker](smokers.usize())
    _rounds = rounds

    for i in Range[U64](0, smokers) do
      _smokers.push(Smoker(this))
    end 

    notifySmoker()

  be started() =>
    if ( _rounds = _rounds - 1 ) > 1 then
      notifySmoker()
    else
      _bench.complete()
    end

  fun ref notifySmoker() =>
    let index = _random.nextInt().usize() % _smokers.size()
    try _smokers(index)?.smoke((_random.nextInt(where max = 1000) + 10).u64()) end

actor Smoker
  let _arbiter: Arbiter
  let _random: SimpleRand

  new create(arbiter: Arbiter) =>
    _arbiter = arbiter
    _random = SimpleRand(1234)

  be smoke(period: U64) =>
    _arbiter.started()

    var test: U64 = 0

    for i in Range[U64](0, period) do
      test = test + 1
    end