use "cli"
use "collections"

primitive FjthrputConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("fjthrput", "", [
        OptionSpec.u64(
          "messages",
          "The total number of messages per actor Defaults to 10000."
          where short' = 'm', default' = 10000
        )
        OptionSpec.u64(
          "actors",
          "The total number of actors to be created. Defaults to 60."
          where short' = 'a', default' = 60
        )
        OptionSpec.u64(
          "channels",
          "The number of channels. Currently ignored. Defaults to 1."
          where short' = 'c', default' = 1
        )
        OptionSpec.bool(
          "priorities",
          "Use priorities. Currently ignored. Defaults to true."
          where short' = 'o', default' = true
        )
      ]) ?
    end

actor Fjthrput
  new run(args: Command val, env: Env) =>
    let messages = args.option("messages").u64()
    let actors = args.option("actors").u64()

    let throughputs = Array[Throughput](actors.usize())

    for i in Range[U64](0, actors) do
      throughputs.push(Throughput)
    end

    for j in Range[U64](0, messages) do
      for k in throughputs.values() do
        k.compute()
      end
    end

actor Throughput
  be compute() =>
    let n = F64(37.2).sin()
    let r = n * n

    try
      if r <= 0 then
        error //trick dead code elimination, could use DoNotOptimize-builtin
      end
    end