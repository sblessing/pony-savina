use "cli"
use "random"
use "collections"
use "time"

primitive BarberConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("barber", "", [
        OptionSpec.u64(
          "haircuts",
          "The number of haircuts. Defaults to 5000."
          where short' = 'h', default' = 5000
        )
        OptionSpec.u64(
          "room",
          "The size of the waiting room. Defaults to 1000."
          where short' = 'r', default' = 1000
        )
        OptionSpec.u64(
          "production",
          "The average production rate. Defaults to 1000."
          where short' = 'p', default' = 1000
        )
        OptionSpec.u64(
          "cut",
          "The average haircut rate. Defaults to 1000."
          where short' = 'c', default' = 1000
        )
      ]) ?
    end

primitive BusyWaiter
  fun val apply(wait: U64): U32 =>
    var test: U32 = 0

    for i in Range[U64](0, wait) do
      Rand.next()
      test = test + 1
    end

    test

actor SleepingBarber
  new run(args: Command val, env: Env) =>
    CustomerFactory.serve(
      args.option("haircuts").u64(),
      args.option("production").u64(),
      WaitingRoom(
        args.option("room").u64(), 
        Barber(args.option("cut").u64())
      )
    )

actor WaitingRoom
  var _size: U64
  var _customers: List[Customer]
  var _barber_sleeps: Bool
  var _barber: Barber

  new create(size: U64, barber: Barber) =>
    _size = size
    _customers = List[Customer]
    _barber_sleeps = false
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

  new create(haircut_rate: U64) =>
    _haircut_rate = haircut_rate

  be enter(customer: Customer, room: WaitingRoom) =>
    customer.sit_down()
    BusyWaiter(Rand(Time.now()._2.u64()).int(_haircut_rate) + 10)
    customer.pay_and_leave()
    room.next()
  
  be wait() => 
    None

actor CustomerFactory
  var _number_of_haircuts: U64 
  var _attempts: U64

  var _room: WaitingRoom 

  new serve(haircuts: U64, rate: U64, room: WaitingRoom) =>
    _number_of_haircuts = 0
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
    _number_of_haircuts = _number_of_haircuts + 1

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