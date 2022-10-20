use "cli"
use "collections"
use "time"
use "../../util"

class iso Banking is AsyncActorBenchmark
  var _accounts: U64
  var _transactions: U64
  var _initial: F64
  let _env: Env

  new iso create(accounts: U64, transactions: U64, env: Env) =>
    _accounts = accounts
    _transactions = transactions
    _initial =  2000 //F64.max_value() / ( _accounts * _transactions ).f64()
    _env = env
    // _env.out.print("initial: " + _initial.string())

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Coordinator(c, _accounts, _transactions, _env)

  fun tag name(): String => "Banking 2PC"

actor Coordinator
  let _accounts: Array[Account]
  let _bench: AsyncBenchmarkCompletion
  let _env: Env
  var _count: U64

  new create(c: AsyncBenchmarkCompletion, accounts: U64, transactions: U64, env: Env) =>
    _bench = c
    _env = env
    _accounts = Array[Account]
    _count = 0

    let a1 = recover iso Array[Account] end
    let a2 = recover iso Array[Account] end

    let initial: F64 =  2000 //F64.max_value() / ( _accounts * _transactions ).f64()
    for i in Range[U64](0, accounts) do
      let a = Account(i, initial)
      _accounts.push(a)
      a1.push(a)
      a2.push(a)
    end

    Teller(this, initial, consume a1, transactions, env)
    Teller(this, initial, consume a2, transactions, env)

  be done() =>
    if (_count = _count + 1) == 1 then
      _bench.complete()
    end

actor Manager
  var _commit: Bool
  var _waiting : U8
  let _teller: Teller
  let _accounts: Array[Account]

  new create(teller: Teller, waiting: U8) =>
    _commit = true
    _waiting = waiting
    _accounts = Array[Account]
    _teller = teller

  fun ref _decide(account: Account, commit: Bool) =>
    _accounts.push(account)
    if (_waiting = _waiting - 1) == 1 then
      if _commit and commit then
        for a in _accounts.values() do
          a.commit()
        end
      else
        for a in _accounts.values() do
          a.abort()
        end
      end
      _teller.completed()
    else
      _commit = _commit and commit
    end

  be yes(account: Account) => _decide(account where commit = true)

  be no(account: Account) => _decide(account where commit = false)

actor Teller
  //let _bench: AsyncBenchmarkCompletion
  let _coordinator: Coordinator
  let _initial_balance: F64
  let _transactions: U64

  var _spawned: U64
  // var _pending: (None | (U32, U32, U64, Bool))

  let _random: SimpleRand

  var _completed: U64
  var _accounts: Array[Account]

  var _finals: Array[F64]
  let _env: Env

  var _retry: U64

  var _acquired: (None | U64)
  var _pending: (None | (U64, U64))

  new create(coordinator: Coordinator, initial_balance: F64, accounts: Array[Account] iso, transactions: U64, env: Env) =>
    _coordinator = coordinator
    _initial_balance = initial_balance
    _transactions = transactions
    _spawned = 0
    _random = SimpleRand(123456)
    _completed = 0
    _accounts = consume accounts
    _finals = Array[F64].init(0, _accounts.size().usize())
    _env = env

    _retry = 0
    _acquired = None
    _pending = None

    _next_transaction()

  be _next_transaction() =>
    match _pending
      | let _: None =>
        if _spawned < _transactions then
          let source = _random.nextInt(where max = _accounts.size().u32() - 1).u64()
          var dest = _random.nextInt(where max = _accounts.size().u32() - 1).u64()

          // TODO
          while source == dest do
            dest = _random.nextInt(where max = _accounts.size().u32() - 1).u64()
          end

          try
            _accounts(source.min(dest).usize())?.acquire(this)
          end
          _pending = (source, dest)
        end
      | (let source: U64, let dest: U64) =>
        try
          _accounts(source.min(dest).usize())?.acquire(this)
        end
    end

  fun ref _reply(index: U64, acquired: Bool) =>
      match _acquired
        | let _: None =>
          if not acquired then
            _retry = _retry + 1
            _next_transaction()
          else // acquire the next account
            match _pending
              | (let source: U64, let dest: U64) =>
                _acquired = index
                try
                  _accounts(source.max(dest).usize())?.acquire(this)
                end
            end
          end
        | let acc: U64 => true
          if not acquired then
            _retry = _retry + 1
            try
              _accounts(acc.usize())?.release(this)
            end
            _next_transaction()
          else
            match _pending
              | (let source: U64, let dest: U64) =>

                let manager = Manager(this, 2)
                let amount = _random.nextDouble() * 1000
                try
                  _accounts(source.usize())?.credit(amount, manager)
                  _accounts(dest.usize())?.debit(amount, manager)

                  _accounts(source.usize())?.release(this)
                  _accounts(dest.usize())?.release(this)
                end
                _spawned = _spawned + 1

                _acquired = None
                _pending = None
                _retry = 0
                _next_transaction()
            end
          end
      end

  be yes(index: U64) => _reply(index where acquired = true)

  be no(index: U64) => _reply(index where acquired = false)

  be completed() =>
    _completed = _completed + 1

    if _completed == _transactions then
      _coordinator.done()
    end

  be tell_balance(index: U64, amount: F64) =>
    try
      _finals(index.usize())? = amount
      if (_completed = _completed + 1) == (_accounts.size() - 1).u64() then
        for i in Range[U64](0, _finals.size().u64()) do
          _env.out.print(i.string() + ": " + _finals(i.usize())?.string())
        end
        // _bench.complete()
      end
    end

class DebitMessage
  let amount: F64
  let manager: Manager

  new create(amount': F64, manager': Manager) =>
    amount = amount'
    manager = manager'

class CreditMessage
  let amount: F64
  let manager: Manager

  new create(amount': F64, manager': Manager) =>
    amount = amount'
    manager = manager'

type StashToken is (DebitMessage | CreditMessage)

actor Account
  let index: U64
  var balance: F64

  var rollback: F64

  var stash: Array[StashToken]
  var stash_mode: Bool

  var acquired: Bool

  new create(index': U64, balance': F64) =>
    index = index'
    balance = balance'

    stash = Array[StashToken]
    stash_mode = false

    acquired = false

    rollback = 0

  be unstash() =>
    try
      match stash.shift()?
        | let m: CreditMessage => _credit(m.amount, m.manager)
        | let m: DebitMessage => _debit(m.amount, m.manager)
      end
    else
      stash_mode = false
    end

  be acquire(teller: Teller) =>
    if acquired then
      teller.no(index)
    else
      acquired = true
      teller.yes(index)
    end

  be release(teller: Teller) =>
    acquired = false
    // teller.ack()

  be commit() =>
    rollback = 0
    unstash()

  be abort() =>
    balance = balance - rollback
    rollback = 0
    unstash()

  fun ref _debit(amount: F64, manager: Manager) =>
    if balance >= amount then
      balance = balance - amount
      rollback = -amount
      manager.yes(this)
    else
      rollback = 0
      manager.no(this)
    end

  fun ref _credit(amount: F64, manager: Manager) =>
    balance = balance + amount
    rollback = amount
    manager.yes(this)

  be debit(amount: F64, manager: Manager) =>
    if not stash_mode then
      stash_mode = true
      _debit(amount, manager)
    else
      stash.push(DebitMessage(amount, manager))
    end

  be credit(amount: F64, manager: Manager) =>
    if not stash_mode then
      stash_mode = true
      _credit(amount, manager)
    else
      stash.push(CreditMessage(amount, manager))
    end

  be get_balance(teller: Teller) =>
    teller.tell_balance(index, balance)