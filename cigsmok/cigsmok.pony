use "cli"
use "collections"
use "random"

primitive CigsmokConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("cigsmok", "", [
        OptionSpec.u64(
          "rounds",
          "The number of rounds. Defaults to 1000."
          where short' = 'r', default' = 1000
        )
        OptionSpec.u64(
          "smokers",
          "The number of smokers. Defaults to 200."
          where short' = 's', default' = 200
        )
      ]) ?
    end

actor Cigsmok
  new run(args: Command val, env: Env) =>
    Arbiter(args.option("rounds").u64(), args.option("smokers").u64())

actor Arbiter
  var _smokers: Array[Smoker]
  var _random: Rand
  var _rounds: U64

  new create(rounds: U64, smokers: U64) =>
    _smokers = Array[Smoker](smokers.usize())
    _random = Rand(rounds * smokers)
    _rounds = rounds

    for i in Range[U64](0, smokers) do
      _smokers.push(Smoker(this))
    end 

    notifySmoker()

  be started() =>
    if ( _rounds = _rounds - 1 ) > 1 then
      notifySmoker()
    end

  fun ref notifySmoker() =>
    let index = _random.next().abs().usize() % _smokers.size()
    try _smokers(index)?.smoke(_random.int(1000) + 10) end

actor Smoker
  let _arbiter: Arbiter

  new create(arbiter: Arbiter) =>
    _arbiter = arbiter

  be smoke(period: U64) =>
    _arbiter.started()

    var test: U64 = 0

    for i in Range[U64](0, period) do
      Rand.next()
      test = test + 1
    end