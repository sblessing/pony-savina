use "cli"

//use "concurrency/banking"
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
//use "parallel/facloc"
//use "parallel/filterbank"
//use nqueenk = "parallel/nqueenk"
//use pi = "parallel/piprecision"
//use "parallel/quicksort"
use "parallel/radixsort"
use recmatsmul = "parallel/recmatmul"
use "parallel/sieve"
//use "parallel/sor"
use trapezoid = "parallel/trapezoid"
use "parallel/uct"

interface Configurable
  fun val apply(): CommandSpec iso^ ?

interface BenchmarkRunner
  new run(args: Command val, env: Env)

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
            ]
          )?
        end

      let command = parse(consume spec, env) ?

      if command.option("list").bool() == true then
        //env.out.print("Banking")
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
        //env.out.print("Filterbank")             
        //env.out.print("Nqueenk")
        //env.out.print("Piprecision")
        //env.out.print("Quicksort")
        env.out.print("Radixsort")
        env.out.print("Recmatmul")
        env.out.print("Sieve")
        //env.out.print("Sor")
        env.out.print("Trapezoid")
        env.out.print("Uct")
      else
        match command.option("benchmark").string()
        //| "Banking" => Banking.run(parse(BankingConfig() ?, env) ?, env)
        | "Barber"  => barber.SleepingBarber.run(parse(barber.BarberConfig() ?, env) ?, env)
        | "BndBuffer" => bndbuffer.BndBuffer.run(parse(bndbuffer.BndBufferConfig() ?, env) ?, env)
        | "Cigsmok" => Cigsmok.run(parse(CigsmokConfig() ?, env) ?, env)
        | "Concdict" => Concdict.run(parse(ConcdictConfig() ?, env) ?, env)
        | "Concsll" => concsll.Concsll.run(parse(concsll.ConcsllConfig() ?, env) ?, env)
        | "Logmap" => Logmap.run(parse(LogmapConfig() ?, env) ?, env)
        | "Philosopher" => DiningPhilosophers.run(parse(PhilosopherConfig() ?, env) ?, env)
        | "Big"     => Big.run(parse(BigConfig() ?, env) ?, env)
        | "Chameneos" => Chameneos.run(parse(ChameneosConfig() ?, env) ?, env)
        | "Count" => Count.run(parse(CountConfig() ?, env) ?, env)
        | "Fib"     => Fib.run(parse(FibConfig() ?, env) ?, env)
        | "Fjcreate" => Fjcreate.run(parse(FjcreateConfig() ?, env) ?, env)
        | "Fjthrput" => Fjthrput.run(parse(FjthrputConfig() ?, env) ?, env)
        | "PingPong" => PingPong.run(parse(PingPongConfig() ?, env) ?, env)
        | "Threadring" => ThreadRing.run(parse(ThreadRingConfig() ?, env) ?, env)
        //| "Apsp"    => Apsp.run(parse(ApspConfig() ?, env) ?, env)
        //| "Astar"   => Astar.run(parse(AstarConfig() ?, env) ?, env)
        //| "Bitonicsort" => Bitonicsort.run(parse(BitonicsortConfig() ?, env) ?, env)
        //| "Facloc" => Facloc.run(parse(FaclocConfig() ?, env) ?, env)				
        //| "Filterbank"   => Filterbank.run(parse(FilterbankConfig() ?, env) ?, env)
        //| "Nqueenk" => nqueenk.Nqueenk.run(parse(nqueenk.NqueenkConfig() ?, env) ?, env)
        //| "Piprecision" => pi.Piprecision.run(parse(pi.PiprecisionConfig() ?, env) ?, env)
        //| "Quicksort" => Quicksort.run(parse(QuicksortConfig() ?, env) ?, env)
        | "Radixsort" => Radixsort.run(parse(RadixsortConfig() ?, env) ?, env)
        | "Recmatmul" => recmatmul.Recmatmul.run(parse(recmatmul.RecmatmulConfig() ?, env) ?, env)
        | "Sieve" => Sieve.run(parse(SieveConfig() ?, env) ?, env)
        //| "Sor" => Sor.run(parse(SorConfig() ?, env) ?, env)
        | "Trapezoid" => trapezoid.Trapezoid.run(parse(trapezoid.TrapezoidConfig() ?, env) ?, env)
        | "Uct" => Uct.run(parse(UctConfig() ?, env) ?, env)
        else
          error
        end
      end
    end
    
    fun tag parse(spec: CommandSpec iso, env: Env): Command val ? =>
      recover
        match CommandParser(consume spec).parse(env.args, env.vars)
        | let command: Command box => command
        | let help: CommandHelp => help.print_help(env.out) ; env.exitcode(0) ; error
        | let syntax: SyntaxError => env.out.print(syntax.string()) ; env.exitcode(1) ; error
        end
      end
