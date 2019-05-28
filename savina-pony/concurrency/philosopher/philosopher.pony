use "collections"
use "../../util"

class iso DiningPhilosophers is AsyncActorBenchmark
  let _philosophers: U64
  let _rounds: U64
  let _channels: U64

  new iso create(philosophers: U64, rounds: U64, channels: U64) =>
    _philosophers = philosophers
    _rounds = rounds
    _channels = channels
  
  fun box apply(c: AsyncBenchmarkCompletion) =>
    let arbitator = Arbitrator(c, _philosophers)
    let actors = Array[Philosopher](_philosophers.usize())

    for i in Range[U64](0, _philosophers) do
      actors.push(Philosopher(
        i.usize(),
        _rounds,
        arbitator
      ))
    end

    for j in Range[USize](0, actors.size()) do
      try actors(j)?.start() end
    end
  
  fun tag name(): String => "Dining Philosophers"

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
    else
      _arbitator.finished()
    end  

actor Arbitrator
  let _bench: AsyncBenchmarkCompletion
  var _forks: Array[Bool]
  var _philosophers: U64
  var _done: U64

  new create(c: AsyncBenchmarkCompletion, philosophers: U64) =>
    _bench = c
    _forks = Array[Bool].init(false, philosophers.usize())
    _philosophers = philosophers
    _done = philosophers

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
  
  be finished() =>
    if (_done = _done - 1) == 1 then
      _bench.complete()
    end
    
