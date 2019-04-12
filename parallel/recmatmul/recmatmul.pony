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

actor Master
  let _env: Env
  let _workers: Array[Worker]
  let _length: U64
  let _num_blocks: U64

  let _matrix_a: Array[Array[U64] val] val
  let _matrix_b: Array[Array[U64] val] val
  let _matrix_c: Array[Array[U64]]

  var _sent: U64
  var _received: U64

  new create(env: Env, workers: U64, data_length: U64, threshold: U64) =>
    _env = env
    _workers = Array[Worker](workers.usize())
    _length = data_length
    _num_blocks = data_length * data_length
    _sent = 0
    _received = 0

    let a: Array[Array[U64] val] iso = recover Array[Array[U64] val] end
    let b: Array[Array[U64] val] iso = recover Array[Array[U64] val] end
      
    // Initialize the matrix
    // This should actually happen outside
    // the benchmark iteration.
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
      _workers.push(Worker(this, _matrix_a, _matrix_b, threshold))
    end

    _send_work(0, 0, 0, 0, 0, 0, 0, _num_blocks, data_length)

  fun ref _send_work(priority: U64, srA: U64, scA: U64, srB: U64, scB: U64, srC: U64, scC: U64, length: U64, dimension: U64) =>
    if (_received == 0) or (_received < _sent) then
      try 
        _workers((srC + scC).usize() % _workers.size())?.work(priority, srA, scA, srB, scB, srC, scC, length, dimension) 
        _sent = _sent + 1
      end
    end

  be work(priority: U64, srA: U64, scA: U64, srB: U64, scB: U64, srC: U64, scC: U64, length: U64, dimension: U64) =>
    _send_work(priority, srA, scA, srB, scB, srC, scC, length, dimension)

  be report(result: Array[Array[U64] val] val, srC: U64, scC: U64, dimension: U64) =>
    var i = srC.usize()
    var j = scC.usize()
    var k = USize(0)
    var l = USize(0)
    let dim = dimension.usize()

    while i < dim do
      while j < dim do
        let r = try result(k)?(l)? else _env.out.print("fail!") end
        try _matrix_c(i)?(j)? = r end
        j = j + 1
        l = l + 1
      end
      i = i + 1
      k = k + 1
    end

  be done() =>
    _received = _received + 1

    if _received == _sent then
      var is_valid = true

      for i in Range[USize](0, _length.usize()) do
        for j in Range[USize](0, _length.usize()) do
          try
            let result = _matrix_c(i)?(j)?
            let expected: U64 = _length * i.u64() * j.u64()
            
            if result != expected then
              _env.out.print(result.string() + " = " + expected.string())
              is_valid = false
              break
            end
          else
            is_valid = false
            break
          end
        end

        if not is_valid then
          break
        end
      end

      _env.out.print("  Result valid = " + is_valid.string())
    end

actor Worker
  let _master: Master
  let _matrix_a: Array[Array[U64] val] val
  let _matrix_b: Array[Array[U64] val] val
  let _threshold: U64
  var _did_work: Bool

  new create(master: Master, a: Array[Array[U64] val] val, b: Array[Array[U64] val] val, threshold: U64) =>
    _master = master
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
      let blocks = dimension.usize()
      var i: USize = 0
      var j: USize = 0

      _master.report(
        recover
          var matrix_c = Array[Array[U64] val]

          while i < blocks do
            var inner = recover Array[U64].init(U64(0), blocks) end

            while j < blocks do
              var k: USize = 0

              while k < blocks do
                try 
                  inner(j)? = _matrix_a(i)?(scA.usize() + k)? * _matrix_b(srB.usize() + k)?(j)? 
                end 
                k = k + 1
              end
            
              j = j + 1
            end

            i = i + 1

            matrix_c.push(consume inner)
          end

          consume matrix_c
        end,
        srC,
        scC,
        dimension
      )
    end

    _master.done()