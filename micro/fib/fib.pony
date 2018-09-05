use "cli"

primitive FibConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("fib", "", [
        OptionSpec.u64(
          "index",
          "The index of the fibonacci number to compute. Defaults to 30."
          where short' = 'i', default' = 30
        )
      ]) ?
    end

actor Fib
  new run(args: Command val, env: Env) =>
    var n = args.option("index").u64().i64()
    Fibonacci.root(n, env) 

actor Fibonacci
  var _parent: (Fibonacci | None)
  var _env: (Env | None)
  var _responses: U64
  var _result: U64

  new root(n: I64, env: Env) =>
    _parent = None
    _env = env
    _responses = 0
    _result = 0

    _compute(n)

  new request(parent': Fibonacci, n: I64) =>
    _parent = parent'
    _env = None
    _responses = 0
    _result = 0

    _compute(n)    

  be response(n: U64) =>
    _result = _result + n
    _responses = _responses + 1

    if _responses == 2 then
      _propagate()
    end

  fun ref _compute(n: I64) =>
    if n <= 2 then
      _result = 1
      _propagate()
    else
      Fibonacci.request(this, n-1)
      Fibonacci.request(this, n-2)
    end 

  fun ref _propagate() =>
    match (_parent, _env)
    | (let parent': Fibonacci, None) => parent'.response(_result)
    | (None, let env: Env) => env.out.print(" Result = " + _result.string()) 
    end