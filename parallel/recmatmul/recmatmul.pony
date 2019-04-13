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
          "threshold",
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

actor Recmatmul
  new run(args: Command val, env: Env) =>
    let workers = args.option("workers").u64()
    let data_length = args.option("length").u64()
    let threshold = args.option("threshold").u64()
    
    Master(env, workers, data_length, threshold)

actor Collector
  let _length: U64
  var _result: Array[Array[U64]]

  new create(length: U64) =>
    _length = length
    _result = Array[Array[U64]].init(Array[U64].init(U64(0), _length.usize()), length.usize()) 
  
  fun box _validate(): Bool =>
    var i: USize = 0
    var j: USize = 0
    let size = _length.usize()

    while i < size do
      while j < size do
        try
          let actual = _result(i)?(j)?
          let expected: U64 = _length * i.u64() * j.u64()
            
          if actual != expected then
            @printf[I32]((actual.string() + " = " + expected.string() + "\n").cstring())
            return false
          end
        else
          return false
        end

        j = j + 1
      end

      i = i + 1
    end

    true

  be collect(partial_result: Array[(USize, USize, U64)] val) =>
    for n in Range[USize](0, partial_result.size()) do
      try
        let coord = partial_result(n)?
        let i = coord._1
        let j = coord._2
        let r = coord._3

        _result(i)?(j)? = r
      end
    end
  
  fun _final() =>
    @printf[I32]((" Result valid = " + _validate().string() + "\n").cstring())


actor Master
  let _env: Env
  let _workers: Array[Worker]
  let _length: U64
  let _num_blocks: U64

  let _matrix_a: Array[Array[U64] iso] val
  let _matrix_b: Array[Array[U64] iso] val
  let _collector: Collector

  var _sent: U64
  var _received: U64

  new create(env: Env, workers: U64, data_length: U64, threshold: U64) =>
    _env = env
    _workers = Array[Worker](workers.usize())
    _length = data_length
    _num_blocks = data_length * data_length
    _sent = 0
    _received = 0
    _collector = Collector(data_length)

    let size = _length.usize()

    var a: Array[Array[U64] iso] iso = recover Array[Array[U64] iso] end
    var b: Array[Array[U64] iso] iso = recover Array[Array[U64] iso] end 

    try
      for i in Range[USize](0, size) do
        a(i)? = recover Array[U64].init(U64(0), size) end
        b(i)? = recover Array[U64].init(U64(0), size) end

        for j in Range[USize](0, size) do
          a(i)?(j)? = i.u64()
          b(i)?(j)? = j.u64()
        end
      end
    end

    (_matrix_a, _matrix_b) = (consume a, consume b)
 
    for k in Range[USize](0, workers.usize()) do
      _workers.push(Worker(this, _collector, _matrix_a, _matrix_b, threshold))
    end

    _send_work(0, 0, 0, 0, 0, 0, 0, _num_blocks, data_length)

  fun ref _send_work(priority: U64, srA: U64, scA: U64, srB: U64, scB: U64, srC: U64, scC: U64, length: U64, dimension: U64) =>
    try 
      _workers((srC + scC).usize() % _workers.size())?.work(priority, srA, scA, srB, scB, srC, scC, length, dimension) 
      _sent = _sent + 1
    end
    
  be work(priority: U64, srA: U64, scA: U64, srB: U64, scB: U64, srC: U64, scC: U64, length: U64, dimension: U64) =>
    _send_work(priority, srA, scA, srB, scB, srC, scC, length, dimension)

actor Worker
  let _master: Master
  let _collector: Collector
  let _matrix_a: Array[Array[U64] iso] val
  let _matrix_b: Array[Array[U64] iso] val
  let _threshold: U64
  var _did_work: Bool

  new create(master: Master, collector: Collector, a: Array[Array[U64] iso] val, b: Array[Array[U64] iso] val, threshold: U64) =>
    _master = master
    _collector = collector
    _matrix_a = a
    _matrix_b = b
    _threshold = threshold
    _did_work = false
  
  be work(priority: U64, srA: U64, scA: U64, srB: U64, scB: U64, srC: U64, scC: U64, length: U64, dimension: U64) =>
    if length > _threshold then
      let new_priority = priority + 1
      let new_dimension = dimension / 2
      let new_length = length / 4

      _master.work(new_priority, srA, scA, srB, scB, srC, scC, new_length, new_dimension)
      _master.work(new_priority, srA, scA + new_dimension, srB + new_dimension, scB, srC, scC, new_length, new_dimension)
      _master.work(new_priority, srA, scA, srB, scB + new_dimension, srC, scC + new_dimension, new_length, new_dimension)
      _master.work(new_priority, srA, scA + new_dimension, srB + new_dimension, scB + new_dimension, srC, scC + new_dimension, new_length, new_dimension)
      _master.work(new_priority, srA + new_dimension, scA, srB, scB, srC + new_dimension, scC, new_length, new_dimension)
      _master.work(new_priority, srA + new_dimension, scA + new_dimension, srB + new_dimension, scB, srC + new_dimension, scC, new_length, new_dimension)
      _master.work(new_priority, srA + new_dimension, scA, srB, scB + new_dimension, srC + new_dimension, scC + new_dimension, new_length, new_dimension)
      _master.work(new_priority, srA + new_dimension, scA + new_dimension, srB + new_dimension, scB + new_dimension, srC + new_dimension, scC + new_dimension, new_length, new_dimension)
    else
      var i: USize = srC.usize()
      let dim = dimension.usize()
      let endR = i + dim
      let endC = scC.usize() + dim 
      
      _collector.collect(
        recover
          var partial_result = Array[(USize, USize, U64)]

          while i < endR do
            var j: USize = scC.usize()
           
            while j < endC do
              var k: USize = 0
              var product: U64 = 0

              while k < dim do
                try
                  product = product + ( _matrix_a(i)?(scA.usize() + k)? * _matrix_b(srB.usize() + k)?(j)? )
                end
                k = k + 1
              end

              partial_result.push((i,j,product))
            
              j = j + 1
            end

            i = i + 1
          end

          consume partial_result
        end
      )
    end