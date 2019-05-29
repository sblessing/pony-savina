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
  let _parseable: Bool
  let _samples: Array[F64]

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

    if not _parseable then
      "".join(
        [ Format(_benchmark where width = 31)
          Format(_mean().string() + " ms" where width = 18, align = AlignRight)
          Format(_median().string() + " ms" where width = 18, align = AlignRight)
          Format("±" + _error().string() + " %" where width = 18, align = AlignRight)
        ].values())
    else
      ",".join([
        _benchmark
        _mean().string()
        _median().string()
        _error().string()
      ].values())
    end
  
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
    let size = _samples.size() 

    if size == 0 then
      0
    else
      let middle = size / 2

      try
        if (size % 2) == 1 then
          _samples(middle)?
        else
          (_samples(middle - 1)? + _samples(middle)?) / 2
        end
      else
        0
      end
    end

  fun ref _geometric_mean(): F64 =>
    var result: F64 = 0

    for i in Range[USize](0, _samples.size()) do
       try result = result + _samples(i)?.log10() end
    end
    
    F64(10).pow(result / _samples.size().f64())

  fun ref _harmonic_mean(): F64 =>
    var denom: F64 = 0

    for i in Range[USize](0, _samples.size()) do
      try denom = denom + ( 1 / _samples(i)?) end
    end

    _samples.size().f64() / denom

  fun ref _stddev(): F64 =>
    let mean = _mean()
    var temp: F64 = 0

    for i in Range[USize](0, _samples.size()) do
      try 
        let sample = _samples(i)?
        temp = temp + ((mean - sample) * (mean - sample))
      end
    end

    (temp / _samples.size().f64()).sqrt()
  
  fun ref _error(): F64 =>
    F64(100) * ((_confidence_high() - _mean()) / _mean())

  fun ref _variation(): F64 =>
   _stddev() / _mean()

  fun ref _confidence_low(): F64 =>
    _mean() - (F64(1.96) * (_stddev() / _samples.size().f64().sqrt()))

  fun ref _confidence_high(): F64 =>
    _mean() + (F64(1.96) * (_stddev() / _samples.size().f64().sqrt()))

   fun ref _skewness(): F64 =>
     let mean = _mean()
     let sd = _stddev()
     var sum: F64 = 0
     var diff: F64 = 0

     if _samples.size() > 0 then
       for i in Range[USize](0, _samples.size()) do
         try
           diff = _samples(i)? - mean
           sum = sum + (diff * diff * diff)
         end
       end

       sum / ((_samples.size().f64() - 1) * sd * sd * sd) 
     else
       0
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
          Format("mean" where width = 18, align = AlignRight)
          Format("median" where width = 18, align = AlignRight)
          Format("error" where width = 18, align = AlignRight)
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

  fun ref summarize(benchmark: AsyncActorBenchmark tag) ? =>
     _print(_results(benchmark)?())
    
actor Savina
  let _benchmarks: List[(U64, AsyncActorBenchmark iso)] iso
  let _output: OutputManager iso
  let _env: Env
  var _start: U64
  var _end: U64
  var _running: Bool

  new create(env: Env, runner: BenchmarkRunner, parseable: Bool) =>
    _benchmarks = recover List[(U64, AsyncActorBenchmark iso)] end
    _output = OutputManager(env, parseable)
    _env = env
    _start = 0
    _end = 0
    _running = false

    runner.benchmarks(this)
  
  fun ref _next() =>
    if not _running then
      try
        // Trigger GC next time the Savina actor is scheduled
        @pony_triggergc[None](@pony_ctx[Pointer[None]]())

        _start = Time.nanos()
    
        recover 
          (var i: U64, let run: AsyncActorBenchmark iso) = _benchmarks.shift()?

          _output.prepare(run)
          
          run(this)
   
          if (i = i - 1) > 1 then
            _benchmarks.unshift((i, consume run))
          else
            _output.summarize(run) ?
          end
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