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
    _env.out.print("done")
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
  var _pending: (None | (U32, U32, U64, Bool))

  let _random: SimpleRand

  var _completed: U64
  var _accounts: Array[Account]

  var _finals: Array[F64]
  let _env: Env

  var _retry: U64
  

  new create(coordinator: Coordinator, initial_balance: F64, accounts: Array[Account] iso, transactions: U64, env: Env) =>
    _coordinator = coordinator
    _initial_balance = initial_balance
    _transactions = transactions
    _spawned = 0
    _pending = None
    _random = SimpleRand(123456)
    _completed = 0
    _accounts = consume accounts
    _finals = Array[F64].init(0, _accounts.size().usize())
    _env = env

    _retry = 0

    _next_transaction()

  be _next_transaction() =>
    match _pending
      | let _: None =>
        if _spawned < _transactions then
          let source = _random.nextInt(where max = _accounts.size().u32() - 1)
          var dest = _random.nextInt(where max = _accounts.size().u32() - 1)

          // TODO
          while source == dest do
            dest = _random.nextInt(where max = _accounts.size().u32() - 1)
          end

          try
            let source_account = _accounts(source.usize()) ?
            let dest_account = _accounts(dest.usize()) ?
            _pending = (source, dest, 2, true)

            if (source < dest) then
              source_account.ready(this)
              dest_account.ready(this)
            else
              dest_account.ready(this)
              source_account.ready(this)
            end
          end
        else
          _env.out.print("enqueued all")
        end
      | (let source: U32, let dest: U32, let count: U64, let outcome: Bool) =>
        try
          let source_account = _accounts(source.usize()) ?
          let dest_account = _accounts(dest.usize()) ?
          _pending = (source, dest, 2, true)

          if (source < dest) then
            source_account.ready(this)
            dest_account.ready(this)
          else
            dest_account.ready(this)
            source_account.ready(this)
          end
        end
    end

  fun ref _decide(send: Bool) =>
    match _pending
      | (let source: U32, let dest: U32, let count: U64, let outcome: Bool) =>
        if (count - 1) == 0 then
          if outcome and send then
            let manager = Manager(this, 2)
            let amount = _random.nextDouble() * 1000
            try
              _accounts(source.usize())?.credit(amount, manager)
              _accounts(dest.usize())?.debit(amount, manager)
            end
            // _env.out.print(_spawned.string())
            _spawned = _spawned + 1
            _pending = None
            _retry = 0
          else
            _retry = _retry + 1
            if (_retry > 100) and ((_retry % 10) == 0) then
              _env.out.print("retry: " + _retry.string() + " " + source.string() + "->" + dest.string())
            end
            // retry
            // _env.out.print("retry")
            try
              _accounts(source.usize())?.abort()
              _accounts(dest.usize())?.abort()
            end
          end
          _next_transaction()
        else
          _pending = (source, dest, count - 1, outcome and send)
        end
    end

  be yes() => _decide(where send = true)

  be no() => _decide(where send = false)

  be completed() =>
    // _env.out.print("compelted")
    _completed = _completed + 1

    if _completed == _transactions then
      _coordinator.done()
      // _bench.complete()
      // _completed = 0
      // for account in _accounts.values() do
      //   account.get_balance(this)
      // end
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

  var stash: Array[StashToken]
  var stash_mode: Bool

  var busy: Bool

  var undo: ({(Account ref)} | None)

  new create(index': U64, balance': F64) =>
    index = index'
    balance = balance'

    stash = Array[StashToken]
    stash_mode = false

    busy = false

    undo = None

  be _unstash() =>
    try
      match stash.shift()?
        | let m: CreditMessage => _credit(m.amount, m.manager)
        | let m: DebitMessage => _debit(m.amount, m.manager)
      end
    else
      stash_mode = false
    end

  be ready(teller: Teller) =>
    if busy then
      teller.no()
    else
      busy = true
      teller.yes()
      undo = ({(account: Account ref) => account.busy = false })
    end

  be commit() =>
    undo = None
    _unstash()

  be abort() =>
    match undo
      | let _: None => true
      | let f: {(Account ref)} =>
        f(this)
        undo = None
    end

  fun ref _debit(amount: F64, manager: Manager) =>
    if balance >= amount then
      balance = balance - amount
      undo = ({(account: Account ref) => account.balance = account.balance + amount })
      manager.yes(this)
    else
      undo = None
      manager.no(this)
    end

  fun ref _credit(amount: F64, manager: Manager) =>
    balance = balance + amount
    undo = ({(account: Account ref) => account.balance = account.balance - amount })
    manager.yes(this)

  be debit(amount: F64, manager: Manager) =>
    if not stash_mode then
      stash_mode = true
      _debit(amount, manager)
    else
      stash.push(DebitMessage(amount, manager))
    end
    busy = false

  be credit(amount: F64, manager: Manager) =>
    if not stash_mode then
      stash_mode = true
      _credit(amount, manager)
    else
      stash.push(CreditMessage(amount, manager))
    end
    busy = false

  be get_balance(teller: Teller) =>
    teller.tell_balance(index, balance)