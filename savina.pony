use "cli"

use "apsp"
use "astar"
use "barber"
use "banking"
use "fib"
use "big"
use "bitonicsort"
use "threadring"
use "pingpong"
use "count"
use bndbuffer = "bndbuffer"
use "chameneos"
use "cigsmok"
use "concdict"
use concsll = "concsll"
use "fjcreate"
use "fjthrput"
use "sieve"
use trapezoid = "trapezoid"
use pi = "piprecision"
use "uct"
use "facloc"
use nqueenk = "nqueenk"
use recmatmul = "recmatmul"

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
                "List the names of available benchmarks, to be used a runner arguments"
                where short' = 'l', default' = false
              )
            ]
          )?
        end

      let command = parse(consume spec, env) ?

      if command.option("list").bool() == true then
        env.out.print("Apsp")
        env.out.print("Astar")
        env.out.print("Barber")
        env.out.print("Banking")
        env.out.print("Fib")
        env.out.print("Big")
        env.out.print("Bitonicsort")
        env.out.print("Threadring")
        env.out.print("PingPong")
        env.out.print("Count")
        env.out.print("BndBuffer")
        env.out.print("Chameneos")
        env.out.print("Cigsmok")
        env.out.print("Concdict")
        env.out.print("Concsll")
        env.out.print("Fjcreate")
        env.out.print("Fjthrput")
        env.out.print("Sieve")
        env.out.print("Trapezoid")
        //env.out.print("Piprecision")
        env.out.print("Uct")
        env.out.print("Facloc")
        //env.out.print("Nqueenk")
        env.out.print("Recmatmul")
      else
        match command.option("benchmark").string()
        | "Apsp"    => Apsp.run(parse(ApspConfig() ?, env) ?, env)
        | "Astar"   => Astar.run(parse(AstarConfig() ?, env) ?, env)
        | "Barber"  => SleepingBarber.run(parse(BarberConfig() ?, env) ?, env)
        | "Banking" => Banking.run(parse(BankingConfig() ?, env) ?, env)
        | "Fib"     => Fib.run(parse(FibConfig() ?, env) ?, env)
        | "Big"     => Big.run(parse(BigConfig() ?, env) ?, env)
        | "Bitonicsort" => Bitonicsort.run(parse(BitonicsortConfig() ?, env) ?, env)
        | "Threadring" => ThreadRing.run(parse(ThreadRingConfig() ?, env) ?, env)
        | "PingPong" => PingPong.run(parse(PingPongConfig() ?, env) ?, env)
        | "Count" => Count.run(parse(CountConfig() ?, env) ?, env)
        | "BndBuffer" => bndbuffer.BndBuffer.run(parse(bndbuffer.BndBufferConfig() ?, env) ?, env)
        | "Chameneos" => Chameneos.run(parse(ChameneosConfig() ?, env) ?, env)
        | "Cigsmok" => Cigsmok.run(parse(CigsmokConfig() ?, env) ?, env)
        | "Concdict" => Concdict.run(parse(ConcdictConfig() ?, env) ?, env)
        | "Concsll" => concsll.Concsll.run(parse(concsll.ConcsllConfig() ?, env) ?, env)
        | "Fjcreate" => Fjcreate.run(parse(FjcreateConfig() ?, env) ?, env)
        | "Fjthrput" => Fjthrput.run(parse(FjthrputConfig() ?, env) ?, env)
        | "Sieve" => Sieve.run(parse(SieveConfig() ?, env) ?, env)
        | "Trapezoid" => trapezoid.Trapezoid.run(parse(trapezoid.TrapezoidConfig() ?, env) ?, env)
        | "Piprecision" => pi.Piprecision.run(parse(pi.PiprecisionConfig() ?, env) ?, env)
        | "Uct" => Uct.run(parse(UctConfig() ?, env) ?, env)
        | "Facloc" => Facloc.run(parse(FaclocConfig() ?, env) ?, env)
        | "Nqueenk" => nqueenk.Nqueenk.run(parse(nqueenk.NqueenkConfig() ?, env) ?, env)
        | "Recmatmul" => recmatmul.Recmatmul.run(parse(recmatmul.RecmatmulConfig() ?, env) ?, env)
        else
          error
        end
      end
    end
    
    fun tag parse(spec: CommandSpec iso, env: Env): Command val ? =>
      recover
        match CommandParser(consume spec).parse(env.args, env.vars())
        | let command: Command box => command
        | let help: CommandHelp => help.print_help(env.out) ; env.exitcode(0) ; error
        | let syntax: SyntaxError => env.out.print(syntax.string()) ; env.exitcode(1) ; error
        end
      end
