use "cli"
use "random"
use "collections"
use "time"
use "../../util"

primitive UctConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("uct", "", [
        OptionSpec.u64(
          "nodes",
          "The maximum number of nodes. Defaults to 200000."
          where short' = 'n', default' = 200000
        )
        OptionSpec.u64(
          "avg",
          "The average computation size. Defaults to 500."
          where short' = 'a', default' = 500
        )
        OptionSpec.u64(
          "stddev",
          "The standard deviation of the computation size. Defaults to 100."
          where short' = 's', default' = 100
        )
        OptionSpec.u64(
          "binomial",
          "Binomial parameter. Each node may have either 0 or binomial children. Defaults to 10."
          where short' = 'i', default' = 10
        )
        OptionSpec.u64(
          "urgent",
          "The percentage of urgend nodes. Defaults to 50."
          where short' = 'p', default' = 50
        )
      ]) ?
    end

primitive BusyWaiter
  fun val apply(wait: U64, multiplier: U64): U32 =>
    var test: U32 = 0
    var current: U64 = Time.millis()

    for i in Range[U64](0, wait * multiplier) do
      test = test + 1
    end

    test
    
class iso Uct is AsyncActorBenchmark
  let _nodes: U64
  let _avg: U64
  let _stddev: U64
  let _binomial: U64
  let _urgent: U64

  new iso create(nodes: U64, avg: U64, stddev: U64, binomial: U64, urgent: U64) =>
    _nodes = nodes
    _avg = avg
    _stddev = stddev
    _binomial = binomial
    _urgent = urgent
  
  fun box apply(c: AsyncBenchmarkCompletion) =>
    Root.generate(
      c, 
      _nodes,
      _binomial,
      _avg,
      _stddev,
      _urgent
    )
  
  fun tag name(): String => "Unbalanced Cobwebbed Tree"
    
actor Root
  let _bench: AsyncBenchmarkCompletion
  let _max_nodes: U64
  let _binomial: U64
  let _avg: U64
  let _stddev: U64
  let _urgent: U64

  var _random: CongruentialRand
  var _height: U64
  var _size: U64
  var _children: Array[Node]
  var _has_grant_children: Array[Bool]
  var _final: Bool
  var _traversed: Bool

  new generate(c: AsyncBenchmarkCompletion, max_nodes: U64, binomial: U64, avg: U64, stddev: U64, urgent: U64) =>
    _bench = c
    _max_nodes = max_nodes
    _binomial = binomial
    _avg = avg
    _stddev = stddev
    _urgent = urgent
    _random = CongruentialRand(2)
    _height = 1
    _size = 1
    _children = Array[Node](_binomial.usize())
    _has_grant_children = Array[Bool](_binomial.usize())
    _final = false
    _traversed = false

    _generate()

  fun ref _get_next_normal(): U64 =>
    var next = U64(0)

    while next <= 0 do
      let temp = (_random.nextGaussian() * _stddev.f64()) + _avg.f64()
      next = temp.round().u64()
    end

    next

  fun ref _generate() =>
    _height = _height + 1
    let computation_size = _get_next_normal()

    for i in Range[USize](0, _binomial.usize()) do
      _has_grant_children.push(false)
      _children.push(Node(this, this, _size + 1, _binomial, _height, computation_size))
    end

    _size = _size + _binomial

  fun ref _traverse() =>
    if _traversed == false then
      for i in Range[USize](0, _binomial.usize()) do
        try _children(i)?.traverse() end
      end

      _traversed = true
    end

  be grant(id: U64) =>
    try _has_grant_children(id.usize())? = true end

  be check_request(sender: Node, child_height: U64) =>
    if((_size + _binomial) <= _max_nodes) then
      if _random.nextBoolean() == true then
        let percentage = Rand(Time.now()._2.u64()).int(100)
        let computation = _get_next_normal()

        if percentage <= _urgent then
          sender.generate(_size, computation) 
        else
          let child = Rand(Time.now()._2.u64()).int(_binomial)
          sender.generate(_size, computation, true, child)
        end
    
        _size = _size + _binomial

        if (child_height + 1) > _height then
          _height = child_height + 1
        end
      elseif child_height > _height then
        _height = child_height
      end
    else
      if _final != true then
        _bench.complete()
        _final = true
      end

      _traverse()
    end

actor Node
  let _root: Root
  let _parent: (Root | Node)
  let _id: U64
  let _binomial: U64
  let _height: U64
  let _computation_size: U64

  var _has_children: Bool
  var _has_grant_children: Array[Bool]
  var _children: Array[Node]

  new create( root: Root, parent: (Node | Root), id: U64, binomial: U64, height: U64, computation_size: U64, urgent: Bool = false) =>
    _root = root
    _parent = parent
    _id = id
    _binomial = binomial
    _height = height
    _computation_size = computation_size

    _has_children = false
    _has_grant_children = Array[Bool](_binomial.usize())
    _children = Array[Node](_binomial.usize())

    BusyWaiter(100, 40000)
    _root.check_request(this, _height)

  be generate(id: U64, computation_size: U64, urgent: Bool = false, urgent_child_id: U64 = 0) =>
    _parent.grant(_id % _binomial)

    for i in Range[U64](0, _binomial) do
      _children.push(Node(_root, this, id + i, _binomial, _height + 1, computation_size, (urgent and (i == urgent_child_id)))) 
    end

    _has_children = true

  be grant(id: U64) =>
    try _has_grant_children(id.usize())? = true end
 
  be traverse() =>
    BusyWaiter(_computation_size, 40000)

    if _has_children == true then
      for i in Range[USize](0, _binomial.usize()) do
        try _children(i)?.traverse() end
      end
    end