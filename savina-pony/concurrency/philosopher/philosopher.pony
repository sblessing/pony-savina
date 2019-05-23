use "cli"
use "collections"

primitive PhilosopherConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("philosopher", "", [
        OptionSpec.u64(
          "philosophers",
          "The number of philosophers. Defaults to 20."
          where short' = 'n', default' = 20
        )
        OptionSpec.u64(
          "rounds",
          "The number of eating rounds. Defaults to 10000."
          where short' = 'r', default' = 10000
        )
        OptionSpec.u64(
          "channels",
          "The number of channels. Defaults to 1."
          where short' = 'c', default' = 1
        )
      ]) ?
    end

actor DiningPhilosophers
  new run(args: Command val, env: Env) =>
    let philosophers = args.option("philosophers").u64()
    let arbitator = Arbitrator(philosophers)
    let actors = Array[Philosopher](philosophers.usize())

    for i in Range[U64](0, philosophers) do
      actors.push(Philosopher(
        i.usize(),
        args.option("rounds").u64(),
        arbitator
      ))
    end

    for j in Range[USize](0, actors.size()) do
      try actors(j)?.start() end
    end

actor Philosopher
  var _id: USize
  var _local: U64
  var _rounds: U64
  var _arbitator: Arbitrator

  new create(id: USize, rounds: U64, arbitator: Arbitrator) =>
    _id = id
    _local = 0
    _rounds = rounds
    _arbitator = arbitator

  be start() =>
    _arbitator.hungry(this, _id)

  be denied() =>
    _local = _local + 1
    _arbitator.hungry(this, _id)

  be eat() =>
    _arbitator.done(_id)

    if (_rounds = _rounds - 1) >= 1 then
      start()
    end  

actor Arbitrator
  var _forks: Array[Bool]
  var _philosophers: U64

  new create(philosophers: U64) =>
    _forks = Array[Bool].init(false, philosophers.usize())
    _philosophers = philosophers

  be hungry(philosopher: Philosopher, id: USize) =>
    let right_index = (id + 1) % _philosophers.usize()

    try
      let left = _forks(id) ?
      let right = _forks(right_index) ?

      if left or right then
        philosopher.denied()
      else
        _forks(id) ? = true
        _forks(right_index) ? = true
        philosopher.eat()
      end
    end

  be done(id: USize) =>
    try
      _forks(id) ? = false
      _forks((id + 1) % _philosophers.usize()) ? = false
    end
    
