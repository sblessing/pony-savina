use "collections"
use "time"
use "format"
use "term"

trait AsyncActorBenchmark
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool)
  fun tag name(): String

interface tag BenchmarkRunner
  fun tag benchmarks(bench: Savina, env: Env)

interface tag AsyncBenchmarkCompletion 
  be complete()
  be append(s: String)

class Result
  let _benchmark: String
  let _parseable: Bool
  var _samples: Array[F64]

  new create(benchmark: String, parseable: Bool) =>
    _benchmark = benchmark
    _parseable = parseable
    _samples = Array[F64]

  fun ref record(nanos: U64) =>
    _samples.push(nanos.f64())
  fun ref apply(): String =>
    Sort[Array[F64], F64](_samples)

    try
      for i in Range[USize](0, _samples.size()) do
        _samples(i)? = _samples(i)?.f64() / 1000000
      end
    end

    let stats = SampleStats(_samples = Array[F64])

    if not _parseable then
      "".join(
        [ Format(_benchmark where width = 31)
          Format(stats.mean().string() + " ms" where width = 18, align = AlignRight)
          Format(stats.median().string() + " ms" where width = 18, align = AlignRight)
          Format("±" + stats.err().string() + " %" where width = 18, align = AlignRight)
          Format(stats.stddev().string() where width = 18, align = AlignRight)
        ].values())
    else
      ",".join([
        _benchmark
        stats.mean().string()
        stats.median().string()
        stats.err().string()
      ].values())
    end

type ResultsMap is MapIs[AsyncActorBenchmark tag, Result]

class OutputManager
  let _env: Env
  let _parseable: Bool
  let _results: ResultsMap
  var _incoming: (AsyncActorBenchmark tag | None)
  
  new iso create(env: Env, parseable: Bool) =>
    _env = env
    _parseable = parseable
    _results = ResultsMap
    _incoming = None

    if not _parseable then
      _print("".join(
        [ ANSI.bold()
          Format("Benchmark" where width = 31)
          Format("i-mean" where width = 18, align = AlignRight)
          Format("i-median" where width = 18, align = AlignRight)
          Format("i-error" where width = 18, align = AlignRight)
          Format("i-stddev" where width = 18, align = AlignRight)
          ANSI.reset()
        ].values()))
    end

  fun ref _print(s: String) =>
    _env.out.print(s)

  fun ref prepare(benchmark: AsyncActorBenchmark tag) =>
    _incoming = benchmark

    try 
      _results(benchmark)? 
    else 
      _results(benchmark) = Result(benchmark.name(), _parseable)
    end

  fun ref report(nanos: U64) =>
    try
      match _incoming
      | let n: AsyncActorBenchmark tag => _results(n)?.record(nanos)
      end
    end

  fun ref summarize() =>
     match _incoming
     | let n: AsyncActorBenchmark tag => try _print(_results(n)?()) ; _incoming = None end
     end
    
actor Savina
  let _benchmarks: List[(U64, AsyncActorBenchmark iso)] iso
  let _output: OutputManager iso
  let _env: Env
  var _start: U64
  var _end: U64
  var _running: Bool
  var _summarize: Bool

  new create(env: Env, runner: BenchmarkRunner, parseable: Bool) =>
    _benchmarks = recover List[(U64, AsyncActorBenchmark iso)] end
    _output = OutputManager(env, parseable)
    _env = env
    _start = 0
    _end = 0
    _running = false
    _summarize = false

    runner.benchmarks(this, env)
  
  fun ref _next() =>
    if not _running then
      if _summarize then
        _output.summarize() 
        _summarize = false
      end

      try
        // Trigger GC next time the Savina actor is scheduled
        @pony_triggergc[None](@pony_ctx[Pointer[None]]())

        _start = Time.nanos()
    
        _summarize = 
          recover 
            (var i: U64, let run: AsyncActorBenchmark iso) = _benchmarks.shift()?
             
            _output.prepare(run) ; run(this, i == 1) 

            if (i = i - 1) > 1 then
              _benchmarks.unshift((i, consume run))
            end          

            i == 0
          end

        _running = true
      end
    end

  be complete() =>
    _end = Time.nanos()
    _running = false
    _output.report(_end - _start)
    _next()

  be apply(iterations: U64, benchmark: AsyncActorBenchmark iso) =>
    _benchmarks.push((iterations, consume benchmark))
    _next()

  be append(s: String) =>
    _env.out.print(s)