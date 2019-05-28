use "cli"
use "collections"
use "../../util"

/*primitive RecmatmulConfig
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
    end*/

class iso Recmatmul is AsyncActorBenchmark
  let _workers: U64
  let _length: U64
  let _threshold: U64

  new iso create(workers: U64, length: U64, threshold: U64, priorities: U64) =>
    _workers = workers
    _length = length
    _threshold = threshold
  
  fun box apply(c: AsyncBenchmarkCompletion) =>    
    Master(c, _workers, _length, _threshold)
  
  fun tag name(): String => "Recursive Matrix Multiplication"

actor Collector
  let _master: Master
  let _length: U64
  var _result: Array[Array[U64]]

  new create(master: Master, length: U64) =>
    _master = master
    _length = length
    _result = Array[Array[U64]]

    let size = _length.usize()
    var i = USize(0)
    
    while i < size do
      _result.push(Array[U64].init(U64(0), size))
      i = i + 1
    end 
  
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

    _master.done()

actor Master
  let _bench: AsyncBenchmarkCompletion
  let _workers: Array[Worker]
  let _length: U64
  let _num_blocks: U64

  let _matrix_a: Array[Array[U64] val] val
  let _matrix_b: Array[Array[U64] val] val
  let _collector: Collector

  var _sent: U64
  var _num_workers: U64

  new create(c: AsyncBenchmarkCompletion, workers: U64, data_length: U64, threshold: U64) =>
    _bench = c
    _workers = Array[Worker](workers.usize())
    
    _length = data_length
    _num_blocks = data_length * data_length
    _sent = 0
    _num_workers = workers
    _collector = Collector(this, data_length)

    let size = _length.usize()

    var a: Array[Array[U64] val] iso = recover Array[Array[U64] val] end
    var b: Array[Array[U64] val] iso = recover Array[Array[U64] val] end 

    try
      for i in Range[USize](0, size) do
        let aI = recover Array[U64].init(U64(0), size) end
        let bI = recover Array[U64].init(U64(0), size) end

        for j in Range[USize](0, size) do
          aI(j)? = i.u64()
          bI(j)? = j.u64()
        end

        a.push(consume aI)
        b.push(consume bI)
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
  
  be done() =>
    if (_num_workers = _num_workers - 1) == 1 then
      _bench.complete()
    end

actor Worker
  let _master: Master
  let _collector: Collector
  let _matrix_a: Array[Array[U64] val] val
  let _matrix_b: Array[Array[U64] val] val
  let _threshold: U64
  var _did_work: Bool

  new create(master: Master, collector: Collector, a: Array[Array[U64] val] val, b: Array[Array[U64] val] val, threshold: U64) =>
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