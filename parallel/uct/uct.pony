use "cli"
use "random"
use "collections"
use "time"

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
          where short' = 'b', default' = 10
        )
      ]) ?
    end

class CongruentialRand is Random
  var _x: U64
  var _next_gaussian: F64 = 0
  var _has_next_gaussian: Bool = false

  new create(x: U64, y: U64 = 0) =>
    _x = (x xor U64(0x5DEECE66D)) and ((U64(1) << 48) -1)
    next()
    
  fun ref next(): U64 =>
    """
    Congruential pseudorandom number generator,
    as defined by D.H. Lehmer and described by
    Donald E. Knuth.
    See The Art of Computer Programming, Vol. 3,
    Section 3.2.1
    """
    _x = ((_x * U64(0x5DEECE77D)) + U64(0xB)) and ((U64(1) << 48) - 1)

  fun ref nextBoolean(): Bool =>
    (next() >> (U64(48 - 1))) != 0

  fun ref nextDouble(): F64 =>
    let a: U64 = next() >> U64(48 - 26)
    let b: U64 = next() >> U64(48 - 27)

    (((a << 27) + b) / U64(1 << 53)).f64()

  fun ref nextGaussian(): F64 =>
    """
    Returns the next gaussian normally distributed
    random number with mean 0.0 and a standard 
    deviation of 1.0. Implemented using the polar
    method as described by G.E.P Box, M.E. Muller
    and G. Marsaglia.
    See The Art of Computer Programming, Vol. 3,
    Section 3.4.1
    """
    if _has_next_gaussian == true then
      _has_next_gaussian = false
      _next_gaussian
    else
      var v1: F64 = 0
      var v2: F64 = 0
      var s: F64 = 0

      repeat
        v1 = (2 * nextDouble()) - 1
        v2 = (2 * nextDouble()) - 1
        s = (v1 * v1) + (v2 * v2)
      until ((s >= 1) or (s == 0)) end

      let multiplier = F64(-2 * (s.log()/s)).sqrt()
      _next_gaussian = v2 * multiplier
      _has_next_gaussian = true
      v1 * multiplier
    end

primitive BusyWaiter
  fun val apply(wait: U64, multiplier: U64): U32 =>
    var test: U32 = 0
    var current: U64 = Time.millis()

    for i in Range[U64](0, wait * multiplier) do
      test = test + 1
    end

    test
    
actor Uct
  new run(args: Command val, env: Env) =>
    Root.generate(
      env, 
      args.option("nodes").u64(),
      args.option("binomial").u64(),
      args.option("avg").u64(),
      args.option("stddev").u64()
    )
    
actor Root
  let _env: Env
  let _max_nodes: U64
  let _binomial: U64
  let _avg: U64
  let _stddev: U64

  var _random: CongruentialRand
  var _height: U64
  var _size: U64
  var _children: Array[Node]
  var _has_grant_children: Array[Bool]
  var _final: Bool
  var _traversed: Bool

  new generate(env: Env, max_nodes: U64, binomial: U64, avg: U64, stddev: U64) =>
    _env = env
    _max_nodes = max_nodes
    _binomial = binomial
    _avg = avg
    _stddev = stddev
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
      _children.push(Node(_env, this, this, _size + 1, _binomial, _height, computation_size))
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
        sender.generate(_size, _get_next_normal()) 
    
        _size = _size + _binomial

        if (child_height + 1) > _height then
          _height = child_height + 1
        end
      elseif child_height > _height then
        _height = child_height
      end
    else
      if _final != true then
        _env.out.print("final size= " + _size.string())
        _env.out.print("final height= " + _height.string())
        _final = true
      end

      _traverse()
    end

  be print_info() =>
    _env.out.print("0 0 children starts 1")

    for i in Range[USize](0, _binomial.usize()) do
      try _children(i)?.print_info() end
    end

actor Node
  let _env: Env
  let _root: Root
  let _parent: (Root | Node)
  let _id: U64
  let _binomial: U64
  let _height: U64
  let _computation_size: U64

  var _has_children: Bool
  var _has_grant_children: Array[Bool]
  var _children: Array[Node]

  new create(env: Env, root: Root, parent: (Node | Root), id: U64, binomial: U64, height: U64, computation_size: U64) =>
    _env = env
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

  be generate(id: U64, computation_size: U64) =>
    _parent.grant(_id % _binomial)

    for i in Range[U64](0, _binomial) do
      _children.push(Node(_env, _root, this, id + i, _binomial, _height + 1, computation_size)) 
    end

    _has_children = true

  be grant(id: U64) =>
    try _has_grant_children(id.usize())? = true end

  be print_info() =>
    if _has_children = true then
      _env.out.print(_id.string() + " " + _computation_size.string() + " children starts")

      for i in Range[USize](0, _binomial.usize()) do
        try _children(i)?.print_info() end
      end
    else
      _env.out.print(_id.string() + " " + _computation_size.string())
    end
 
  be traverse() =>
    BusyWaiter(_computation_size, 40000)

    if _has_children == true then
      for i in Range[USize](0, _binomial.usize()) do
        try _children(i)?.traverse() end
      end
    end