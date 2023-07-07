use "./util"
use "cli"
use "collections"

use reasonablebanking = "concurrency/banking2pc"
use banking = "concurrency/banking"
use barber = "concurrency/barber"
use bndbuffer = "concurrency/bndbuffer"
use "concurrency/cigsmok"
use "concurrency/concdict"
use concsll = "concurrency/concsll"
use "concurrency/logmap"
use "concurrency/philosopher"

use "micro/big"
use "micro/chameneos"
use "micro/count"
use "micro/fib"
use "micro/fjcreate"
use "micro/fjthrput"
use "micro/pingpong"
use "micro/threadring"

//use "parallel/apsp"
//use "parallel/astar"
//use "parallel/bitonicsort"
//use facloc = "parallel/facloc"
use filterbank = "parallel/filterbank"
//use nqueenk = "parallel/nqueenk"
//use pi = "parallel/piprecision"
use quicksort = "parallel/quicksort"
use radixsort = "parallel/radixsort"
use recmatmul = "parallel/recmatmul"
use "parallel/sieve"
//use "parallel/sor"
use trapezoid = "parallel/trapezoid"
//use "parallel/uct"
use "parallel/chat"

class SavinaRunner is BenchmarkRunner
  let _single : String

  let benches: Array[AsyncActorBenchmark iso] = [
      banking.Banking(1000, 50000)
      barber.SleepingBarber(5000, 1000, 1000, 1000)
      bndbuffer.BndBuffer(50, 40, 40, 1000, 25, 25)
      Cigsmok(1000, 200)
      Concdict(20, 10000, 10)
      concsll.Concsll(20, 8000, 1, 10)
      Logmap(25000, 10, 3.64, 0.0025)
      DiningPhilosophers(20, 10000, 1)
      Big(20000, 120)
      Chameneos(100, 200000)
      Count(1000000)
      Fib(25)
      Fjcreate(40000)
      Fjthrput(10000, 60, 1, true)
      PingPong(40000)
      ThreadRing(100, 100000)
      filterbank.Filterbank(16384, 34816, 8, 100)
      quicksort.Quicksort(1000000, U64(1 << 60), 2048, 1024)
      radixsort.Radixsort(100000, U64(1 << 60), 2048)
      recmatmul.Recmatmul(20, 1024, 16384, 10)
      Sieve(100000, 1000)
      trapezoid.Trapezoid(10000000, 100, 1, 5)
  ]

  new iso create(single: String) =>
    _single = single

  fun ref benchmarks(iterations: U64, bench: Savina, env: Env) =>
    let banking2pc: AsyncActorBenchmark iso = reasonablebanking.Banking(1000, 50000)

    if _single == banking2pc.name() then
      bench(iterations, consume banking2pc)
      return
    end

    while benches.size() > 0 do
      try
        let benchmark = benches.pop()?
        if (_single == "") or (_single == benchmark.name()) then
          bench(iterations, consume benchmark)
        end
      end
    end

  fun ref list(env: Env) =>
    env.out.print("Benchmarks:")
    while benches.size() > 0 do
      try
        env.out.print("\t" + (benches.pop()?.name()))
      end
    end
    env.out.print("\t" + (reasonablebanking.Banking(0, 0).name()))

actor Main
  new create(env: Env) =>
    let cs =
      try
        CommandSpec.leaf("savina", "The Savina Benchmark Suite (Pony)", [
          OptionSpec.bool("parseable", "Parseable output format"
            where short' = 'p', default' = false)
          OptionSpec.u64("reps", "Number of repeats for benchmark"
            where short' = 'r', default' = 12)
          OptionSpec.string("benchmark", "Run a single benchmark"
            where short' = 'b', default' = "")
          OptionSpec.bool("list", "list benchmarks"
            where short' = 'l', default' = false)
        ])? .> add_help()?
      else
        env.exitcode(-1)
        return
      end

    let cmd =
      match CommandParser(cs).parse(env.args, env.vars)
      | let c: Command => c
      | let ch: CommandHelp =>
          ch.print_help(env.out)
          env.exitcode(0)
          return
      | let se: SyntaxError =>
          env.out.print(se.string())
          env.exitcode(1)
          return
      end

    let runner = SavinaRunner(cmd.option("benchmark").string())

    if cmd.option("list").bool() then
      runner.list(env)
      env.exitcode(0)
      return
    end

    Savina(env, consume runner, cmd.option("parseable").bool(), cmd.option("reps").u64())