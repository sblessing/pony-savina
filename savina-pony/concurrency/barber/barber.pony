use "random"
use "collections"
use "time"
use "../../util"

class  BusyWaiter
  let _rand: Rand

  new create() =>
    _rand = Rand

  fun ref apply(wait: U64): U32 =>
    var test: U32 = 0

    for i in Range[U64](0, wait) do
      _rand.next()
      test = test + 1
    end

    test

class iso SleepingBarber is AsyncActorBenchmark
  let _haircuts: U64
  let _room: U64
  let _production: U64
  let _cut: U64

  new iso create(haircuts: U64, room: U64, production: U64, cut: U64) =>
    _haircuts = haircuts
    _room = room
    _production = production
    _cut = cut

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) => 
    CustomerFactory.serve(
      c,
      _haircuts,
      _production,
      WaitingRoom(
        _room, 
        Barber(_cut)
      )
    )   

  fun tag name(): String => "Sleeping Barber" 

actor WaitingRoom
  var _size: U64
  var _customers: List[Customer]
  var _barber_sleeps: Bool
  var _barber: Barber

  new create(size: U64, barber: Barber) =>
    _size = size
    _customers = List[Customer]
    _barber_sleeps = true
    _barber = barber
  
  be enter(customer: Customer) =>
    if _customers.size().u64() == _size then
      customer.full()
    else
      _customers.push(customer)

      if _barber_sleeps then
        _barber_sleeps = false
        next()
      else
        customer.wait()
      end
    end

  be next() =>
    if _customers.size() > 0 then
      try _barber.enter(_customers.shift() ?, this) end
    else
      _barber.wait()
      _barber_sleeps = true
    end
  
actor Barber
  var _haircut_rate: U64
  let _waiter: BusyWaiter

  new create(haircut_rate: U64) =>
    _haircut_rate = haircut_rate
    _waiter = BusyWaiter

  be enter(customer: Customer, room: WaitingRoom) =>
    customer.sit_down()
    _waiter(Rand(Time.now()._2.u64()).int(_haircut_rate) + 10)
    customer.pay_and_leave()
    room.next()
  
  be wait() => 
    None

actor CustomerFactory
  let _bench: AsyncBenchmarkCompletion
  var _number_of_haircuts: U64 
  var _attempts: U64
  var _room: WaitingRoom

  new serve(c: AsyncBenchmarkCompletion, haircuts: U64, rate: U64, room: WaitingRoom) =>
    _bench = c
    _number_of_haircuts = haircuts
    _attempts = 0
    _room = room

    for i in Range[U64](0, haircuts) do
      _attempts = _attempts + 1
      _room.enter(Customer(this))
      BusyWaiter(Rand(Time.now()._2.u64()).int(rate) + 10)
    end
  
  be returned(customer: Customer) =>
    _attempts = _attempts + 1
    _room.enter(customer)

  be left(customer: Customer) =>
    _number_of_haircuts = _number_of_haircuts - 1

    if _number_of_haircuts == 0 then
      _bench.complete()
    end

actor Customer
  var _factory: CustomerFactory

  new create(factory: CustomerFactory) =>
    _factory = factory

  be full() =>
    _factory.returned(this)

  be wait() =>
    None
    
  be sit_down() =>
    None
  
  be pay_and_leave() =>
    _factory.left(this)