use "./util"
use "cli"

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

actor Main is BenchmarkRunner
  new create(env: Env) =>
    let cs =
      try
        CommandSpec.leaf("savina", "The Savina Benchmark Suite (Pony)", [
          OptionSpec.bool("parseable", "Parseable output format"
            where short' = 'p', default' = false)
          OptionSpec.u64("reps", "Number of repeats for benchmark"
            where short' = 'r', default' = 12)
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

    Savina(env, this, cmd.option("parseable").bool(), cmd.option("reps").u64())

  fun tag benchmarks(iterations: U64, bench: Savina, env: Env) =>
    bench(iterations, banking.Banking(1000, 50000))
    bench(iterations, barber.SleepingBarber(5000, 1000, 1000, 1000))
    bench(iterations, bndbuffer.BndBuffer(50, 40, 40, 1000, 25, 25))
    bench(iterations, Cigsmok(1000, 200))
    bench(iterations, Concdict(20, 10000, 10))
    bench(iterations, concsll.Concsll(20, 8000, 1, 10))
    bench(iterations, Logmap(25000, 10, 3.64, 0.0025))
    bench(iterations, DiningPhilosophers(20, 10000, 1))
    bench(iterations, Big(20000, 120))
    bench(iterations, Chameneos(100, 200000))
    bench(iterations, Count(1000000))
    bench(iterations, Fib(25))
    bench(iterations, Fjcreate(40000))
    bench(iterations, Fjthrput(10000, 60, 1, true))
    bench(iterations, PingPong(40000))
    bench(iterations, ThreadRing(100, 100000))
    //bench(Apsp)
    //bench(Astar)
    //bench(Bitonicsort)
    //bench(Facloc)
    bench(iterations, filterbank.Filterbank(16384, 34816, 8, 100))
    //bench(Nqueenk)
    //bench(pi.Piprecision)
    bench(iterations, quicksort.Quicksort(1000000, U64(1 << 60), 2048, 1024))
    bench(iterations, radixsort.Radixsort(100000, U64(1 << 60), 2048))
    bench(iterations, recmatmul.Recmatmul(20, 1024, 16384, 10))
    bench(iterations, Sieve(100000, 1000))
    //bench(Sor)
    bench(iterations, trapezoid.Trapezoid(10000000, 100, 1, 5))
    //bench(iterations, Uct(200000, 500, 100, 10, 50))
    // bench(iterations, ChatApp(env))