use "collections"
use "time"
use "format"
use "term"

trait AsyncActorBenchmark
  fun box apply(c: AsyncBenchmarkCompletion)
  fun tag name(): String

interface tag BenchmarkRunner
  fun tag benchmarks(bench: Savina)

interface tag AsyncBenchmarkCompletion 
  be complete()

class Result
  let _benchmark: String
  let _samples: Array[F64]

  new create(benchmark: String) =>
    _benchmark = benchmark
    _samples = Array[F64]

  fun ref record(nanos: U64) =>
    _samples.push(nanos.f64())
  
  fun ref apply(): String =>
    Sort[Array[F64], F64](_samples)

    try
      for i in Range[USize](0, _samples.size()) do
        _samples(i)? = _samples(i)?.f64() / F64(1000000)
      end
    end

    "".join(
      [ Format(_benchmark where width = 30)
        Format(_mean().string() + " ms" where width = 18, align = AlignRight)
        Format(_median().string() + " ms" where width = 18, align = AlignRight)
        Format("±" + _stddev().string() + "%" where width = 13, align = AlignRight)
      ].values()
    )
  
  fun ref _sum(): F64 =>
    var sum: F64 = 0

    try
      for i in Range(0, _samples.size()) do
        sum = sum + _samples(i)?
      end
    end

    sum

  fun ref _mean(): F64 =>
    (_sum() / _samples.size().f64())

  fun ref _median(): F64 =>
    try
      let len = _samples.size()
      let i = len / 2
      if (len % 2) == 1 then
        _samples(i)?.f64()
      else
        (let lo, let hi) = (_samples(i)?, _samples(i + 1)?)
        ((lo.f64() + hi.f64()) / 2).round()
      end
    else
      0
    end

  fun ref _stddev(): F64 =>
    // sample standard deviation
    if _samples.size() < 2 then return 0 end
    try
      var sum_squares: F64 = 0
      for i in Range(0, _samples.size()) do
        let n = _samples(i)?.f64()
        sum_squares = sum_squares + (n * n)
      end
      let avg_squares = sum_squares / _samples.size().f64()
      let mean' = _mean()
      let mean_sq = mean' * mean'
      let len = _samples.size().f64()
      ((len / (len - 1)) * (avg_squares - mean_sq)).sqrt()
    else
      0
    end

type ResultsMap is MapIs[AsyncActorBenchmark tag, Result]

class OutputManager
  let _env: Env
  let _results: ResultsMap
  var _incoming: (AsyncActorBenchmark tag | None)
  
  new iso create(env: Env) =>
    _env = env
    _results = ResultsMap
    _incoming = None

    _print("".join(
      [ ANSI.bold()
        Format("Benchmark" where width = 30)
        Format("mean" where width = 18, align = AlignRight)
        Format("median" where width = 18, align = AlignRight)
        Format("deviation" where width = 12, align = AlignRight)
        ANSI.reset()
      ].values()))

  fun ref _print(s: String) =>
    _env.out.print(s)

  fun ref prepare(benchmark: AsyncActorBenchmark tag) =>
    _incoming = benchmark

    try 
      _results(benchmark)? 
    else 
      _results(benchmark) = Result(benchmark.name())
    end

  fun ref report(nanos: U64) =>
    try
      match _incoming
      | let n: AsyncActorBenchmark tag => _results(n)?.record(nanos)
      end
    end

  fun ref summarize() =>
    try
      for benchmark in _results.keys() do
        _print(_results(benchmark)?())
      end
    end

actor Savina
  let _benchmarks: List[(U64, AsyncActorBenchmark iso)] iso
  let _output: OutputManager iso
  var _start: U64
  var _end: U64
  var _running: Bool

  new create(env: Env, runner: BenchmarkRunner) =>
    _benchmarks = recover List[(U64, AsyncActorBenchmark iso)] end
    _output = OutputManager(env)
    _start = 0
    _end = 0
    _running = false

    runner.benchmarks(this)
  
  fun ref _next() =>
    if not _running then
      try
        _start = Time.nanos()

        recover 
          (var i: U64, let run: AsyncActorBenchmark iso) = _benchmarks.shift()?
  
          i = i - 1

          _output.prepare(run)
          run(this)
   
          if i > 0 then
            _benchmarks.unshift((i, consume run))
          end
        end

        _running = true
      else
        _output.summarize()
      end
    end

  be complete() =>
    _end = Time.nanos()
    _running = false
    _output.report(_end - _start)
    _next()

  be apply(iterations: U64, benchmark: AsyncActorBenchmark iso) =>
    _benchmarks.unshift((iterations, consume benchmark))
    _next()