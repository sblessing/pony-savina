use "cli"

primitive BarberConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("barber", "", [
        OptionSpec.u64(
          "haircuts",
          "The number of haircuts. Defaults to 5000."
          where short' = 'h', default' = 5000
        )
        OptionSpec.u64(
          "room",
          "The size of the waiting room. Defaults to 1000."
          where short' = 'r', default' = 1000
        )
        OptionSpec.u64(
          "production",
          "The average production rate. Defaults to 1000."
          where short' = 'p', default' = 1000
        )
        OptionSpec.u64(
          "cut",
          "The average haircut rate. Defaults to 1000."
          where short' = 'c', default' = 1000
        )
      ]) ?
    end

actor SleepingBarber
  new run(args: Command val, env: Env) =>
    None

/*actor WaitingRoom

actor Barber

actor CustomerFactory

actor Customer*/