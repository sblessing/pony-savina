use "cli"

//use "parallel/apsp"
//use "parallel/astar"
use "concurrency/banking"
use "micro/fib"
//use "parallel/filterbank"
use "micro/fjcreate"
use barber ="concurrency/barber"
use "micro/big"
//use "parallel/bitonicsort"
use bndbuffer = "concurrency/bndbuffer"
use "micro/chameneos"
use "concurrency/cigsmok"
use "concurrency/concdict"
use concsll = "concurrency/concsll"
use "micro/count"
//use "parallel/facloc"
use "micro/fjthrput"
//use "concurrency/logmap"
use nqueenk = "parallel/nqueenk"
//use "concurrency/philosopher"
use "micro/pingpong"
//use pi = "parallel/piprecision"
//use "parallel/quicksort"
//use "parallel/radixsort"
//use recmatmul = "parallel/recmatmul"
use "parallel/sieve"
//use "parallel/sor"
use "micro/threadring"
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
        //env.out.print("Apsp")
        //env.out.print("Astar")
				env.out.print("Banking,Banking")
				env.out.print("Fib,Fibonacci")
				//env.out.print("Filterbank")
				env.out.print("Fjcreate,Fork_Join_(actor_creation)")
        env.out.print("Barber,Barber")        
        env.out.print("Big,Big")
        //env.out.print("Bitonicsort")
				env.out.print("BndBuffer,Producer-Consumer_with_Bounded_Buffer")
				env.out.print("Chameneos,Chameneos")
        env.out.print("Cigsmok,Cigarette_Smokers")
				env.out.print("Concdict,Concurrent_Dictionary")
        env.out.print("Concsll,Concurrent_Sorted_Linked-List")
				env.out.print("Count,Counting_Actor")
				//env.out.print("Facloc")
				env.out.print("Fjthrput,Fork_Join_(throughput)")
				//env.out.print("Logmap")
				//env.out.print("Nqueenk")
				//env.out.print("Philosopher")
				env.out.print("PingPong,Ping_Pong")
				//env.out.print("Piprecision")
				//env.out.print("Quicksort")
				//env.out.print("Radixsort")
				//env.out.print("Recmatmul")
				env.out.print("Sieve,Sieve_of_Eratosthenes")
				//env.out.print("Sor")				 
        env.out.print("Threadring,Thread_Ring")      
        env.out.print("Trapezoid,Trapezoidal_Approximation")
        //env.out.print("Uct")
      else
        match command.option("benchmark").string()
        //| "Apsp"    => Apsp.run(parse(ApspConfig() ?, env) ?, env)
        //| "Astar"   => Astar.run(parse(AstarConfig() ?, env) ?, env)
        | "Banking" => Banking.run(parse(BankingConfig() ?, env) ?, env)
				| "Fib"     => Fib.run(parse(FibConfig() ?, env) ?, env)
        //| "Filterbank"   => Filterbank.run(parse(FilterbankConfig() ?, env) ?, env)
				| "Fjcreate" => Fjcreate.run(parse(FjcreateConfig() ?, env) ?, env)
				| "Barber"  => barber.SleepingBarber.run(parse(barber.BarberConfig() ?, env) ?, env)
        | "Big"     => Big.run(parse(BigConfig() ?, env) ?, env)
        //| "Bitonicsort" => Bitonicsort.run(parse(BitonicsortConfig() ?, env) ?, env)
				| "BndBuffer" => bndbuffer.BndBuffer.run(parse(bndbuffer.BndBufferConfig() ?, env) ?, env)
        | "Chameneos" => Chameneos.run(parse(ChameneosConfig() ?, env) ?, env)
        | "Cigsmok" => Cigsmok.run(parse(CigsmokConfig() ?, env) ?, env)
        | "Concdict" => Concdict.run(parse(ConcdictConfig() ?, env) ?, env)
        | "Concsll" => concsll.Concsll.run(parse(concsll.ConcsllConfig() ?, env) ?, env)
        | "Count" => Count.run(parse(CountConfig() ?, env) ?, env)
        //| "Facloc" => Facloc.run(parse(FaclocConfig() ?, env) ?, env)
        | "Fjthrput" => Fjthrput.run(parse(FjthrputConfig() ?, env) ?, env)
        //| "Logmap" => Logmap.run(parse(LogmapConfig() ?, env) ?, env)
				| "Nqueenk" => nqueenk.Nqueenk.run(parse(nqueenk.NqueenkConfig() ?, env) ?, env)
        //| "Philosopher" => Philosopher.run(parse(PhilosopherConfig() ?, env) ?, env)
		    | "PingPong" => PingPong.run(parse(PingPongConfig() ?, env) ?, env)
				//| "Piprecision" => pi.Piprecision.run(parse(pi.PiprecisionConfig() ?, env) ?, env)
        //| "Quicksort" => Quicksort.run(parse(QuicksortConfig() ?, env) ?, env)
				//| "Radixsort" => Radixsort.run(parse(RadixsortConfig() ?, env) ?, env)
        //| "Recmatmul" => recmatmul.Recmatmul.run(parse(recmatmul.RecmatmulConfig() ?, env) ?, env)
				| "Sieve" => Sieve.run(parse(SieveConfig() ?, env) ?, env)
        //| "Sor" => Sor.run(parse(SorConfig() ?, env) ?, env)
        | "Threadring" => ThreadRing.run(parse(ThreadRingConfig() ?, env) ?, env)
        | "Trapezoid" => trapezoid.Trapezoid.run(parse(trapezoid.TrapezoidConfig() ?, env) ?, env)
        //| "Uct" => Uct.run(parse(UctConfig() ?, env) ?, env)
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
