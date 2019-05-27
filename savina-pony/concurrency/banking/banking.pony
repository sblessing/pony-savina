use "cli"
use "collections"
use "random"
use "time"
use "../../util"

/*primitive BankingConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover 
      CommandSpec.leaf("banking", "", [
        OptionSpec.u64(
          "accounts",
          "The number of accounts managed by each teller T. Defaults to 1000."
          where short' = 'a', default' = 1000
        )
        OptionSpec.u64(
          "transactions",
          "The number of transactions handeled by each teller X. Defaults to 50000."
          where short' = 't', default' = 50000
        )
      ]) ?
    end*/

class iso Banking is AsyncActorBenchmark
  var _accounts: U64
  var _transactions: U64
  var _initial: F64

  new iso create(accounts: U64, transactions: U64 /*args: Command val, env: Env*/) =>
    _accounts = accounts //args.option("accounts").u64()
    _transactions = transactions //args.option("transactions").u64()
    _initial = F64.max_value() / ( _accounts * _transactions ).f64()

  fun box apply(c: AsyncBenchmarkCompletion) => 
    Teller(c, _initial, _accounts, _transactions)

  fun tag name(): String => "Banking"

actor Teller
  let _bench: AsyncBenchmarkCompletion
  let _initial_balance: F64
  let _transactions: U64
  let _random: SimpleRand
  var _completed: U64
  var _accounts: Array[Account]
 
  new create(bench: AsyncBenchmarkCompletion, initial_balance: F64, accounts: U64, transactions: U64) =>
    _bench = bench
    _initial_balance = initial_balance
    _transactions = transactions
    _random = SimpleRand(123456)
    _completed = 0
    _accounts = Array[Account](accounts.usize())
    
    for i in Range[U64](0, accounts) do
      _accounts.push(Account(i, _initial_balance))
    end

    for i in Range[U64](0, _transactions) do
      // Randomly pick source and destination account
      let source = _random.nextMax((_accounts.size().u32() / 10) * 8)
      var dest = _random.nextMax(_accounts.size().u32() - source)

      if dest == 0 then
        dest = dest + 1
      end

      try
        let source_account = _accounts(source.usize()) ?
        let dest_account = _accounts(source.usize() + dest.usize()) ?
        let amount = Rand(Time.now()._2.u64()).real() * 1000

        source_account.credit(this, amount, dest_account)
      end
    end

  be reply() =>
    _completed = _completed + 1

    if _completed == _transactions then
      _bench.complete()
    end

class DebitMessage
  let _account: Account
  let _teller: Teller
  let _amount: F64

  new create(account: Account, teller: Teller, amount: F64) =>
    _account = account
    _teller = teller
    _amount = amount

  fun ref requeue(receiver: Account) =>
    receiver.debit(_account, _teller, _amount)

class CreditMessage
  let _account: Account
  let _teller: Teller
  let _amount: F64

  new create(account: Account, teller: Teller, amount: F64) =>
    _account = account
    _teller = teller
    _amount = amount
  
  fun ref requeue(receiver: Account) =>
    receiver.credit(_teller, _amount, _account)

type StashToken is (DebitMessage | CreditMessage)

class Stash
  let _account: Account
  var _buffer: Array[StashToken]
 
  new create(account: Account) =>
    _account = account
    _buffer = Array[StashToken]
    
  fun ref stash(token: StashToken) =>
    _buffer.push(token)

  fun ref unstash() =>
    try
      while true do
        _buffer.shift()?.requeue(_account)
      end
    end

actor Account
  let _index: U64
  var _balance: F64
  var _stash: Stash
  var _stash_mode: Bool

  new create(index: U64, balance: F64) =>
    _index = index
    _balance = balance
    _stash = Stash(this)
    _stash_mode = false

  be debit(account: Account, teller: Teller, amount: F64) =>
    if not _stash_mode then
      _balance = _balance + amount
      account.reply(teller)
    else
      _stash.stash(DebitMessage(account, teller, amount))
    end

  be credit(teller: Teller, amount: F64, destination: Account) =>
    if not _stash_mode then
      _balance = _balance - amount
      destination.debit(this, teller, amount)
      _stash_mode = true
    else
      _stash.stash(CreditMessage(destination, teller, amount))
    end  
 
  be reply(teller: Teller) =>
    teller.reply()
    _stash.unstash()
    _stash_mode = false