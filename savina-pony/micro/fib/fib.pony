use "../../util"

class iso Fib is AsyncActorBenchmark
  let _index: U64

  new iso create(index: U64) =>
    _index = index
  
  fun box apply(c: AsyncBenchmarkCompletion) =>
    Fibonacci.root(c, _index.i64()) 
  
  fun tag name(): String => "Fib"

actor Fibonacci
  let _bench: (AsyncBenchmarkCompletion | None)
  var _parent: (Fibonacci | None)
  var _responses: U64
  var _result: U64

  new root(c: AsyncBenchmarkCompletion, n: I64) =>
    _bench = c
    _parent = None
    _responses = 0
    _result = 0

    _compute(n)

  new request(parent': Fibonacci, n: I64) =>
    _bench = None
    _parent = parent'
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
    match (_parent, _bench)
    | (let parent': Fibonacci, _) => parent'.response(_result)
    | (None, let bench': AsyncBenchmarkCompletion) => bench'.complete()
    end