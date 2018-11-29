use "cli"
use "collections"

primitive RecmatmulConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("recmatmul", "", [
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 20."
          where short' = 'w', default' = 20
        )
        OptionSpec.u64(
          "length",
          "The data length. Defaults to 1024."
          where short' = 'l', default' = 1024
        )
        OptionSpec.u64(
          "blocks",
          "The block threshold. Defaults to 16384."
          where short' = 't', default' = 16384
        )
        OptionSpec.u64(
          "priorities",
          "The priority levels. Defaults to 10. Maximum value is 29."
          where short' = 'p', default' = 10
        )
      ]) ?
    end

class val WorkCommand
  let _priority: U64
  let _srA: U64
  let _scA: U64
  let _srB: U64
  let _scB: U64
  let _srC: U64
  let _scC: U64
  let _blocks: U64
  let _dimension: U64

  new create(priority: U64, srA: U64, scA: U64, srB: U64, scB: U64, srC: U64, scC: U64, blocks: U64, dimension: U64) =>
    _priority = priority
    _srA = srA
    _scA = scA
    _srB = srB
    _scB = scB
    _srC = srC
    _scC = scC
    _blocks = blocks
    _dimension = dimension

  fun val getPriority(): U64 =>
    _priority

  fun val getBlocks(): U64 =>
    _blocks

  fun val getDimension(): U64 =>
    _dimension

  fun val getIndex(workers: USize): USize =>
    (_srC + _scC).usize() % workers

  fun val multiply() =>
    None

actor Recmatmul
  new run(args: Command val, env: Env) =>
    let workers = args.option("workers").u64()
    let data_length = args.option("length").u64()
    let threshold = args.option("threshold").u64()
    
    Master(workers, data_length, threshold)

actor Master
  let _workers: Array[Worker]
  let _num_blocks: U64

  let _matrix_a: Array[Array[U64] val] val
  let _matrix_b: Array[Array[U64] val] val
  let _matrix_c: Array[Array[U64]]

  new create(workers: U64, data_length: U64, threshold: U64) =>
    _workers = Array[Worker](workers.usize())
    _num_blocks = data_length * data_length

    let a: Array[Array[U64] val] iso = recover Array[Array[U64] val] end
    let b: Array[Array[U64] val] iso = recover Array[Array[U64] val] end
      
    // Initialize the matrix
    try
      for i in Range[USize](0, data_length.usize()) do
        let aI = recover Array[U64].init(U64(0), data_length.usize()) end
        let bI = recover Array[U64].init(U64(0), data_length.usize()) end

        for j in Range[USize](0, data_length.usize()) do
          aI(j)? = i.u64()
          bI(j)? = j.u64()
        end

        a.push(consume aI)
        b.push(consume bI)
      end
    end

    _matrix_a = consume a 
    _matrix_b = consume b 
    _matrix_c = Array[Array[U64]].init(Array[U64].init(U64(0), data_length.usize()), data_length.usize()) 
 
    for k in Range[USize](0, workers.usize()) do
      _workers.push(Worker(this, threshold))
    end

    _send_work(recover WorkCommand(0, 0, 0, 0, 0, 0, 0, _num_blocks, data_length) end)

  fun ref _send_work(command: WorkCommand val) =>
    let index = command.getIndex(_workers.size())
    try _workers(index)?.work(command) end

  be work(command: WorkCommand val) =>
    _send_work(command)

actor Worker
  let _master: Master
  let _threshold: U64

  new create(master: Master, threshold: U64) =>
    _master = master
    _threshold = threshold
  
  be work(command: WorkCommand val) =>
    let priority = command.getPriority()
    let length = command.getBlocks()
    let dimension = command.getDimension()
    
    if dimension > _threshold then
      let new_priority = priority + 1
      let new_dimension = dimension / 2
      let new_length = length / 4

      //TODO
      //_master.work(
      //  WorkCommand(new_priority, )
      //)
    else
      command.multiply()
    end