use "cli"
use "collections"
use "random"
use "time"

primitive BankingConfig
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
    end

actor Banking
  var _accounts: U64
  var _transactions: U64
  var _initial: F64

  new run(args: Command val, env: Env) =>
    _accounts = args.option("accounts").u64()
    _transactions = args.option("transactions").u64()
    _initial = F64.max_value() / ( _accounts * _transactions ).f64()

    Teller(_initial, _accounts, _transactions)

actor Teller
  let _initial_balance: F64
  let _transactions: U64
  var _completed: U64
  var _accounts: Array[Account]
 
  new create(initial_balance: F64, accounts: U64, transactions: U64) =>
    _initial_balance = initial_balance
    _transactions = transactions
    _completed = 0
    _accounts = Array[Account](accounts.usize())
    
    for i in Range[U64](0, accounts) do
      _accounts.push(Account(i, _initial_balance))
    end

    for i in Range[U64](0, _transactions) do
      // Randomly pick source and destination account
      let source = Rand(Time.now()._2.u64()).int[U64]((_accounts.size().u64() / 10) * 8)
      let dest = Rand(Time.now()._2.u64()).int[U64](_accounts.size().u64() - source)

      try
        let source_account = _accounts(source.usize()) ?
        let dest_account = _accounts(source.usize() + dest.usize()) ?
        let amount = Rand(Time.now()._2.u64()).real() * 1000     

        source_account.credit(this, amount, dest_account)
      end
    end

  be reply() =>
    _completed = _completed + 1

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
        let message = _buffer.shift()?
        message.requeue(_account)
      end

      true
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
      _stash.unstash()
    else
      _stash.stash(DebitMessage(account, teller, amount))
    end

  be credit(teller: Teller, amount: F64, destination: Account) =>
    if not _stash_mode then
      _balance = _balance - amount
      destination.debit(this, teller, amount)
    else
      _stash.stash(CreditMessage(destination, teller, amount))
    end

    _stash_mode = true
 
  be reply(teller: Teller) =>
    teller.reply()
    _stash.unstash()
    _stash_mode = false