use "cli"
use "random"
use "collections"

primitive ApspConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("apsp", "", [
        OptionSpec.u64(
          "nodes",
          "The number of nodes in the input graph. Defaults to 300."
          where short' = 'n', default' = 300
        )
        OptionSpec.u64(
          "blocks",
          "The block size handeled by each worker. Defaults to 50."
          where short' = 's', default' = 50
        )
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 100."
          where short' = 'w', default' = 100
        )
      ]) ?
    end 

class Data
  var _graph: Array[Array[U64]]

  new create(nodes: U64, workers: U64) /*?*/ =>
    _graph = Array[Array[U64]]
    let size = nodes.usize()
    
    for i in Range[USize](0, size) do
      _graph.push(Array[U64].init(U64(0), size))

      /*for j in Range[USize](i+1, size) do
        _graph(i)?.push(Array[U64].init(U64(0), size))
        let value = Rand.int[U64](workers) + 1

        try
          _graph(i)?(j)? = value
          _graph(j)?(i)? = value
        end
      end*/
    end
    
actor Apsp
  new run(command: Command val, env: Env) =>
    None