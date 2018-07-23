use "cli"

primitive BitonicsortConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("bitonicsort", "", [
        OptionSpec.u64(
          "size",
          "The data set size. Must be power of two. Defaults to 4096."
          where short' = 's', default' = 4096
        )
        OptionSpec.u64(
          "maximum",
          "The maximum value. Defaults to 1L << 60."
          where short' = 'm', default' = (U64(1) << 60)
        )
        OptionSpec.u64(
          "seed",
          "A seed for random number generator. Defaults to 2048."
          where short' = 'r', default' = 2048
        )
      ]) ?
    end

actor Bitonicsort
  var _size: U64 = 0
  var _maximum: U64 = 0
  var _seed: U64 = 0

  new run(args: Command val, env: Env) =>
    _size = args.option("size").u64()
    _maximum = args.option("maximum").u64()
    _seed = args.option("seed").u64()

    let validator = Validation(_size)
    let adapter = Adapter(validator)
    let kernel = Kernel(_size, true, adapter)
    let source = Source(_size, _maximum, _seed, kernel)

actor Validation
  new create(size: U64) =>
    None

actor Adapter
  new create(v: Validation) =>
    None

actor Kernel
  new create(size: U64, direction: Bool, next: Adapter) =>
    None

actor Source
  new create(size: U64, maximum: U64, seed: U64, kernel: Kernel) =>
    None