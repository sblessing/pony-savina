use "cli"

primitive CountConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("count", "", [
        OptionSpec.u64(
          "messages",
          "The number of messages. Defaults to 1000000."
          where short' = 'n', default' = 1000000
        )
      ]) ?
    end

actor Count
  let _messages: U64

  new run(args: Command val, env: Env) =>
    _messages = args.option("messages").u64()
    Producer.increment(Counter, _messages, env)

actor Counter
  var _count: U64 = 0

  be increment() =>
    _count = _count + 1

  be retrieve(sender: Producer) =>
    sender.result(_count)
  
actor Producer
  let _messages: U64
  let _env: Env

  new increment(counter: Counter, messages: U64, env: Env) =>
    _messages = messages
    _env = env

    var i: U64 = 0

    while i < _messages do
      counter.increment()
      i = i + 1
    end
    
    counter.retrieve(this)
  
  be result(result': U64)
    if result' != _messages then
      _env.out.print("ERROR: expected: " + _messages.string() + ", found: " + result'.string())
    else
      _env.out.print("SUCCESS! received: " + result'.string())
    end

  

