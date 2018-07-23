use "cli"

primitive AstarConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("astar", "", [
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 20."
          where short' = 'w', default' = 20
        )
        OptionSpec.u64(
          "threshold",
          "The threshold. Defaults to 1024."
          where short' = 't', default' = 1024
        )
        OptionSpec.u64(
          "grid",
          "The grid size. Defaults to 30."
          where short' = 'g', default' = 30
        )
        OptionSpec.u64(
          "priorities",
          "The number of priority levels. Defaults to 30."
          where short' = 'p', default' = 30
        )
      ]) ?
    end

actor Astar
  new run(args: Command val, env: Env) =>
    None