use "cli"
use "collections"
use "random"
use "time"

primitive ConcdictConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("concdict", "", [
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 100."
          where short' = 'w', default' = 100
        )
        OptionSpec.u64(
          "messages",
          "The number of messages per worker. Defaults to 1000000."
          where short' = 'm', default' = 1000000
        )
        OptionSpec.u64(
          "percentage",
          "The write percentage threshold. Defaults to 10."
          where short' = 'p', default' = 85
        )
      ]) ?
    end

actor Concdict
  new run(args: Command val, env: Env) =>
    Master(
      args.option("workers").u64(), 
      args.option("messages").u64(),
      args.option("percentage").u64()
    )

actor Master
  new create(workers: U64, messages: U64, percentage: U64) =>
    let dictionary = Dictionary

    for i in Range[U64](0, workers) do
      Worker(this, dictionary, messages, percentage).work()
    end

actor Worker
  var _messages: U64
  let _percentage: U64
  let _dictionary: Dictionary

  new create(master: Master, dictionary: Dictionary, messages: U64, percentage: U64) =>
    _messages = messages
    _percentage = percentage
    _dictionary = dictionary

  be work(value: U64 = 0) =>
    if (_messages = _messages - 1) > 1 then
      var value' = Rand(Time.now()._2.u64()).int(100)
      value' = value' % (I64.max_value() / 4096).u64()

      if value' < _percentage then
        _dictionary.write(this, value', value')
      else
        _dictionary.read(this, value')
      end
    end    

actor Dictionary
  var _map: HashMap[U64, U64, HashEq[U64]]

  new create() =>
    _map = HashMap[U64, U64, HashEq[U64]](U32.max_value().usize() / 4096)

  be write(worker: Worker, key: U64, value: U64) =>
    _map.add(key, value)
    worker.work(value)

  be read(worker: Worker, key: U64) =>
    try worker.work(_map(key) ?) end