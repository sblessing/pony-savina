use "cli"

primitive PingPongConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("pingpong", "", [
        OptionSpec.u64(
          "pings",
          "The number of pings. Defaults to 9000000."
          where short' = 'n', default' = 9000000
        )
      ]) ?
    end

actor PingPong
  new run(args: Command val, env: Env) =>
    Ping(args.option("pings").u64(), Pong)

actor Ping
  var _left: U64
  var _pong: Pong

  new create(pings: U64, pong': Pong) =>
    _left = pings - 1
    _pong = pong'
    _pong.ping(this)

  be pong() =>
    if _left > 0 then
      _pong.ping(this)
      _left = _left - 1
    end

actor Pong
  var _count: U64 = 0

  be ping(sender: Ping) =>
    sender.pong()
    _count = _count + 1
