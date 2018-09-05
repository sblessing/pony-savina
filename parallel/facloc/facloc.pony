use "cli"

primitive FaclocConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("facloc", "", [
        OptionSpec.u64(
          "points",
          "The number of points. Defaults to 100000."
          where short' = 'p', default' = 100000
        )
        OptionSpec.u64(
          "grid",
          "The grid size. Defaults to 500."
          where short' = 'g', default' = 500
        )
        OptionSpec.u64(
          "alpha",
          "The alpha value. Defaults to 2."
          where short' = 'a', default' = 2
        )
        OptionSpec.u64(
          "seed",
          "The seed. Defauls to 123456."
          where short' = 's', default' = 123456
        )
        OptionSpec.u64(
          "cutoff",
          "The cutoff depth. Defauls to 3."
          where short' = 's', default' = 3
        )
      ]) ?
    end

actor Facloc
  new run(args: Command val, env: Env) =>
    None