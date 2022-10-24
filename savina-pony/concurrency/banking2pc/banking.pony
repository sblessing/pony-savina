use "cli"
use "collections"
use "time"
use "../../util"

class iso Banking is AsyncActorBenchmark
  var _accounts: U64
  var _transactions: U64

  new iso create(accounts: U64, transactions: U64) =>
    _accounts = accounts
    _transactions = transactions

  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Coordinator(c, _accounts, _transactions)

  fun tag name(): String => "Banking 2PC"

actor Coordinator
  let _accounts: Array[Account]
  let _bench: AsyncBenchmarkCompletion
  var _count: U64
  let _tellers: U64

  new create(c: AsyncBenchmarkCompletion, accounts: U64, transactions: U64) =>
    _bench = c
    _accounts = Array[Account]
    _count = 0

    let initial = F64.max_value() / ( accounts * transactions ).f64()
    for i in Range[U64](0, accounts) do
      _accounts.push(Account(i, initial))
    end

    _tellers = 2
    for t in Range[U64](0, _tellers) do
      let accs: Array[Account] iso = Array[Account]
      for a in _accounts.values() do
        accs.push(a)
      end
      Teller(this, initial, consume accs, transactions)
    end

  be done() =>
    if (_count = _count + 1) == (_tellers - 1) then
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
  let _coordinator: Coordinator
  let _initial_balance: F64
  let _transactions: U64

  var _spawned: U64

  let _random: SimpleRand

  var _completed: U64
  var _accounts: Array[Account]

  var _acquired: (None | U64)
  var _pending: (None | (U64, U64))

  new create(coordinator: Coordinator, initial_balance: F64, accounts: Array[Account] iso, transactions: U64) =>
    _coordinator = coordinator
    _initial_balance = initial_balance
    _transactions = transactions
    _spawned = 0
    _random = SimpleRand(123456)
    _completed = 0
    _accounts = consume accounts

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

  fun ref _reply(index: U64) =>
      match _acquired
        | let _: None =>
          match _pending
            | (let source: U64, let dest: U64) =>
              _acquired = index
              try
                _accounts(source.max(dest).usize())?.acquire(this)
              end
          end
        | let acc: U64 => true
          match _pending
            | (let source: U64, let dest: U64) =>

              let manager = Manager(this, 2)
              let amount = _random.nextDouble() * 1000
              try
                _accounts(source.usize())?.credit(amount, manager)
                _accounts(dest.usize())?.debit(amount, manager)
              end
              _spawned = _spawned + 1

              _acquired = None
              _pending = None
              _next_transaction()
          end
      end

  be yes(index: U64) => _reply(index)

  be completed() =>
    _completed = _completed + 1

    if _completed == _transactions then
      _coordinator.done()
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

  var acquire_stash: Array[Teller]
  var acquired: Bool

  new create(index': U64, balance': F64) =>
    index = index'
    balance = balance'

    stash = Array[StashToken]
    stash_mode = false

    acquire_stash = Array[Teller]
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
      acquire_stash.push(teller)
    else
      acquired = true
      teller.yes(index)
    end

  fun ref _release() =>
    acquired = false
    try
      match acquire_stash.shift()?
        | let t: Teller => t.yes(index)
      end
    end

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
    _release()

  be credit(amount: F64, manager: Manager) =>
    if not stash_mode then
      stash_mode = true
      _credit(amount, manager)
    else
      stash.push(CreditMessage(amount, manager))
    end
    _release()
