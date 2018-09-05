use "cli"
use "collections"

primitive FjcreateConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("fjcreate", "", [
        OptionSpec.u64(
          "workers",
          "The total number of actors to create. Defaults to 10000000."
          where short' = 'w', default' = 10000000
        )
      ]) ?
    end

primitive Token

actor Fjcreate
  new run(args: Command val, env: Env) =>
    for i in Range[U64](0, args.option("workers").u64()) do
      ForkJoin(Token)      
    end

actor ForkJoin
  new create(token: Token) =>
    let n = F64(37.2).sin()
    let r = n * n

    try
      if r <= 0 then
        error //trick dead code elimination, could use DoNotOptimize-builtin
      end
    end

    