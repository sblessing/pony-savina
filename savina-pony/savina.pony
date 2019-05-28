use "cli"
use "collections"
use "./util"

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
use "parallel/uct"

actor Main is BenchmarkRunner
  new create(env: Env) =>
    Savina(env, this)

  fun tag benchmarks(bench: Savina) =>
    bench(12, banking.Banking(1000, 50000))
    bench(12, barber.SleepingBarber(5000, 1000, 1000, 1000))
    bench(12, bndbuffer.BndBuffer(50, 40, 40, 1000, 25, 25))
    bench(12, Cigsmok(1000, 200))
    bench(12, Concdict(20, 10000, 10))
    bench(12, concsll.Concsll(20, 8000, 1, 10))
    bench(12, Logmap(25000, 10, 3.64, 0.0025))
    bench(12, DiningPhilosophers(20, 10000, 1))
    bench(12, Big(20000, 120))
    bench(12, Chameneos(100, 200000))
    bench(12, Count(1000000))
    bench(12, Fib(25))
    bench(12, Fjcreate(40000))
    bench(12, Fjthrput(10000, 60, 1, true))
    bench(12, PingPong(40000))
    bench(12, ThreadRing(100, 100000))
    ////bench(Apsp)
    ////bench(Astar)
    ////bench(Bitonicsort)
    ////bench(Facloc)
    bench(12, filterbank.Filterbank(16384, 34816, 8, 100))
    ////bench(Nqueenk)
    ////bench(pi.Piprecision)
    bench(12, quicksort.Quicksort(1000000, U64(1 << 60), 2048, 1024))
    bench(12, radixsort.Radixsort(100000, U64(1 << 60), 2048))
    //bench(12, recmatmul.Recmatmul(20, 1024, 16384, 10))
    bench(12, Sieve(100000, 1000))
    ////bench(Sor)
    bench(12, trapezoid.Trapezoid(1000000, 100, 1, 5))
    //bench(12, Uct(200000, 500, 100, 10, 50))





/*interface Configurable
  fun val apply(): CommandSpec iso^ ?

interface Benchmark
  new setup(args: Command val)
  be run(env: Env)

actor BenchmarkRunner
  new create(benchmark: Benchmark, env: Env, iterations: U64) =>
    for i in Range[U64](0, iterations) do
      benchmark.run(env) // wait until first iteration is done
    end

actor Main
  new create(env: Env) =>
    try
      let spec = 
        recover iso
          CommandSpec.leaf("pony-savina",
            """
            The Pony Savina Benchmark Runner
            """, 
            [
              OptionSpec.string(
                "benchmark",
                "Runs the specific benchmark."
                where short' = 'b', default' = "None"
              )
              OptionSpec.bool(
                "distributed",
                "Enable the distribution actor. Defaults to false."
                where short' = 'd', default' = false
              )
              OptionSpec.bool(
                "list",
                "List the names of available benchmarks, to be used as runner arguments"
                where short' = 'l', default' = false
              )
              OptionSpec.u64(
                "iterations",
                "The number of iterations to be executed. Defaults to 12."
                where short' = 'i', default' = 12
              )
            ]
          )?
        end

      let command = parse(consume spec, env) ?

      if command.option("list").bool() == true then
        env.out.print("Banking")
        env.out.print("Barber") 
        env.out.print("BndBuffer")
        env.out.print("Cigsmok")
        env.out.print("Concdict")
        env.out.print("Concsll")
        env.out.print("Logmap")
        env.out.print("Philosopher")
        env.out.print("Big")
        env.out.print("Chameneos")
        env.out.print("Count")
        env.out.print("Fib")
        env.out.print("Fjcreate")
        env.out.print("Fjthrput")
        env.out.print("PingPong")
        env.out.print("Threadring") 
        //env.out.print("Apsp")
        //env.out.print("Astar")
        //env.out.print("Bitonicsort")
        //env.out.print("Facloc")			
        env.out.print("Filterbank")             
        //env.out.print("Nqueenk")
        //env.out.print("Piprecision")
        env.out.print("Quicksort")
        env.out.print("Radixsort")
        env.out.print("Recmatmul")
        env.out.print("Sieve")
        //env.out.print("Sor")
        env.out.print("Trapezoid")
        env.out.print("Uct")
      else
        BenchmarkRunner(
          match command.option("benchmark").string()
          | "Banking" => banking.Banking.setup(parse(banking.BankingConfig() ?, env) ?)
          | "Barber"  => barber.SleepingBarber.setup(parse(barber.BarberConfig() ?, env) ?)
          | "BndBuffer" => bndbuffer.BndBuffer.setup(parse(bndbuffer.BndBufferConfig() ?, env) ?)
          | "Cigsmok" => Cigsmok.setup(parse(CigsmokConfig() ?, env) ?)
          | "Concdict" => Concdict.setup(parse(ConcdictConfig() ?, env) ?)
          | "Concsll" => concsll.Concsll.setup(parse(concsll.ConcsllConfig() ?, env) ?)
          | "Logmap" => Logmap.setup(parse(LogmapConfig() ?, env) ?)
          | "Philosopher" => DiningPhilosophers.setup(parse(PhilosopherConfig() ?, env) ?)
          | "Big"     => Big.setup(parse(BigConfig() ?, env) ?)
          | "Chameneos" => Chameneos.setup(parse(ChameneosConfig() ?, env) ?)
          | "Count" => Count.setup(parse(CountConfig() ?, env) ?)
          | "Fib"     => Fib.setup(parse(FibConfig() ?, env) ?)
          | "Fjcreate" => Fjcreate.setup(parse(FjcreateConfig() ?, env) ?)
          | "Fjthrput" => Fjthrput.setup(parse(FjthrputConfig() ?, env) ?)
          | "PingPong" => PingPong.setup(parse(PingPongConfig() ?, env) ?)
          | "Threadring" => ThreadRing.setup(parse(ThreadRingConfig() ?, env) ?)
          //| "Apsp"    => Apsp.run(parse(ApspConfig() ?, env) ?, env)
          //| "Astar"   => Astar.run(parse(AstarConfig() ?, env) ?, env)
          //| "Bitonicsort" => Bitonicsort.run(parse(BitonicsortConfig() ?, env) ?, env)
          //| "Facloc" => facloc.Facloc.run(parse(facloc.FaclocConfig() ?, env) ?, env)				
          | "Filterbank"   => filterbank.Filterbank.setup(parse(filterbank.FilterbankConfig() ?, env) ?)
          //| "Nqueenk" => nqueenk.Nqueenk.run(parse(nqueenk.NqueenkConfig() ?, env) ?, env)
          //| "Piprecision" => pi.Piprecision.run(parse(pi.PiprecisionConfig() ?, env) ?, env)
          | "Quicksort" => quicksort.Quicksort.setup(parse(quicksort.QuicksortConfig() ?, env) ?)
          | "Radixsort" => radixsort.Radixsort.setup(parse(radixsort.RadixsortConfig() ?, env) ?)
          | "Recmatmul" => recmatmul.Recmatmul.setup(parse(recmatmul.RecmatmulConfig() ?, env) ?)
          | "Sieve" => Sieve.run(parse(SieveConfig() ?, env) ?, env)
          //| "Sor" => Sor.run(parse(SorConfig() ?, env) ?, env)
          | "Trapezoid" => trapezoid.Trapezoid.setup(parse(trapezoid.TrapezoidConfig() ?, env) ?)
          | "Uct" => Uct.setup(parse(UctConfig() ?, env) ?)
          else
            error
          end,
          env
          command.options("iterations").u64()
        )
      end
    end
    
    fun tag parse(spec: CommandSpec iso, env: Env): Command val ? =>
      recover
        match CommandParser(consume spec).parse(env.args, env.vars)
        | let command: Command box => command
        | let help: CommandHelp => help.print_help(env.out) ; env.exitcode(0) ; error
        | let syntax: SyntaxError => env.out.print(syntax.string()) ; env.exitcode(1) ; error
        end
      end*/
