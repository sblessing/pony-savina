use "cli"
use "random"
use "collections"

primitive ApspConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("apsp", "", [
        OptionSpec.u64(
          "workers",
          "The number of worker in the input graph. Defaults to 300."
          where short' = 'n', default' = 300
        )
        OptionSpec.u64(
          "blocks",
          "The block size handeled by each worker. Defaults to 50."
          where short' = 's', default' = 50
        )
        OptionSpec.u64(
          "weight",
          "The maximum edge weight. Defaults to 100."
          where short' = 'w', default' = 100
        )
      ]) ?
    end 

class GraphData
  var _workers: U64
  var _size: U64
  var _weight: U64
  var _data: Array[Array[U64]]

  new generate(workers: U64, size: U64, weight: U64) =>
    _workers = workers
    _size = size
    _weight = weight
    
    _data = Array[Array[U64]].init(Array[U64].init(0, _workers.usize()), _workers.usize())

    let random = Rand(_workers)

    for i in Range[USize](0, workers.usize()) do
      for j in Range[USize](0, workers.usize()) do
        let value = random.int(_weight) + 1
        
        try
          _data(i)?(j)? = value
          _data(j)?(i)? = value
        end
      end
    end
    
  
  fun val get_block(id: U64): Array[Array[U64]] val =>
    recover
      var local = Array[Array[U64]].init(Array[U64].init(0, _size.usize()), _size.usize())
      let dim = _workers / _size
      let start_row = ((id / dim) * _size).usize()
      let start_col = ((id % dim) * _size).usize()

      for i in Range[USize](0, _size.usize()) do
        for j in Range[USize](0, _size.usize()) do
          try local(i)?(j)? = _data(i + start_row)?(j + start_col)? end
        end
      end

      local
    end

actor Apsp
  new run(args: Command val, env: Env) =>
    let workers = args.option("workers").u64()
    let size = args.option("blocks").u64()
    let weight = args.option("weight").u64()
    let dim = workers / size
    let data: GraphData val = recover GraphData.generate(workers, size, weight) end

    let block_actors = Array[Array[FloydWarshall]]

    for i in Range[U64](0, dim) do
      var row = Array[FloydWarshall](dim.usize())
      block_actors.push(row)
      
      for j in Range[U64](0, dim) do
        row.push(FloydWarshall((i * dim) + j, workers, size, data))
      end
    end

    for k in Range[USize](0, dim.usize()) do
      for l in Range[USize](0, dim.usize()) do
        let neighbors = recover List[FloydWarshall] end

        for m in Range[USize](0, dim.usize()) do
          if m != k then
            try neighbors.push(block_actors(m)?(l)?) end
          end
        end

        for n in Range[USize](0, dim.usize()) do
          if n != l then
            try neighbors.push(block_actors(k)?(n)?) end
          end
        end

        try block_actors(k)?(l)?.neighbors(consume neighbors) end
      end
    end

    for o in Range[USize](0, dim.usize()) do
      for p in Range[USize](0, dim.usize()) do
        try block_actors(o)?(p)?.start() end
      end
    end

actor FloydWarshall
  var _id: U64
  var _nodes: U64
  var _size: U64
  var _blocks: U64
  var _row_offset: U64
  var _column_offset: U64
  var _count_neighbors: USize
  var _completions: I64
  var _data: GraphData val
  var _neighbors: List[FloydWarshall] val
  var _neighbor_data: Map[U64, Array[Array[U64]] val]
  var _current_data: Array[Array[U64]] val
  var _finished: Bool

  new create(id: U64, nodes: U64, size: U64, data: GraphData val) =>
    _id = id
    _nodes = nodes
    _size = size
    _blocks = nodes / size
    _count_neighbors = (2 * (_blocks - 1)).usize()
    _row_offset = (_id / _blocks) * _size
    _column_offset = (_id % _blocks) * _size
    _completions = -1
    _data = data
    _neighbors = recover List[FloydWarshall] end
    _neighbor_data = Map[U64, Array[Array[U64]] val]
    _current_data = _data.get_block(_id)
    _finished = false

  fun ref _notify() =>
    for neighbor in _neighbors.nodes() do
       try neighbor()?.result(_completions, _id, _current_data) end
    end
    
  fun ref _store(completions: I64, from: U64, data: Array[Array[U64]] val): Bool =>
    _neighbor_data(from) = data
    _neighbor_data.size() == _count_neighbors
  
  fun ref element_at(roffset: U64, coffset: U64): U64 =>
    let row = _row_offset + roffset
    let col = _column_offset + coffset

    let destination = ((row / _size) * _blocks) + (col / _size)
    let rlocal = (row % _size).usize()
    let clocal = (col %_size).usize()
    
    if destination == _id then
      try 
        _current_data(rlocal)?(clocal)?
      else
        0 // should never happen
      end
    else
      try
        let block_data = _neighbor_data(destination)?
        block_data(rlocal)?(clocal)?
      else
        0 // should never happen
      end
    end

  fun ref _compute() =>
    _current_data = recover
      let block_size = _size.usize()

      var new_data = Array[Array[U64]].init(Array[U64].init(0, block_size), block_size)

      for i in Range[USize](0, block_size) do
        for j in Range[USize](0, block_size) do
          let new_value = element_at(i.u64(), _completions.u64()) + element_at(_completions.u64(), j.u64())
          try new_data(i)?(j)? = new_value.min(_current_data(i)?(j)?) end
        end
      end      

      new_data
    end
  
  be neighbors(list: List[FloydWarshall] iso) =>
    _neighbors = consume list

  be start() =>
    _notify()

  be result(completions: I64, from: U64, data: Array[Array[U64]] val) =>
    if _store(completions, from, data) and (not _finished) then
      _completions = _completions + 1
      _compute() ; _notify() ; _neighbor_data = Map[U64, Array[Array[U64]] val]
      _finished = _completions.u64() == (_nodes - 1)
    end