use "cli"
use "../../util"
use "format"
use "collections"

primitive FaclocConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("facloc", "", [
        OptionSpec.u64(
          "points",
          "The number of points. Defaults to 100000."
          where short' = 'p', default' = 100000
        )
        OptionSpec.u64(
          "grid",
          "The grid size. Defaults to 500."
          where short' = 'g', default' = 500
        )
        OptionSpec.u64(
          "alpha",
          "The alpha value. Defaults to 2."
          where short' = 'a', default' = 2
        )
        OptionSpec.u64(
          "seed",
          "The seed. Defauls to 123456."
          where short' = 's', default' = 123456
        )
        OptionSpec.u64(
          "cutoff",
          "The cutoff depth. Defauls to 3."
          where short' = 'c', default' = 3
        )
      ]) ?
    end

primitive Unknown
primitive Root
primitive TopLeft
primitive TopRight
primitive BottomLeft
primitive BottomRight

type Position is 
  ( Unknown
  | Root
  | TopLeft
  | TopRight
  | BottomLeft
  | BottomRight
  )

type PointIterator is Iterator[Point]

primitive PointFactory   
  fun random(r: SimpleRand, size: F64): Point =>
    let x = r.nextDouble() * size
    let y = r.nextDouble() * size

    recover Point(x, y) end
  
  fun find_center(points: PointIterator): Point =>
    var size: F64 = 0
    var sum_x = F64(0)
    var sum_y = F64(0)
    
    for point in points do
      sum_x = sum_x + point.get_x()
      sum_y = sum_y + point.get_y()
      size  = size + 1
    end

    recover Point(sum_x / size, sum_y / size) end

class val Point
  let _x: F64
  let _y: F64

  new create(x: F64, y: F64) =>
    _x = x
    _y = y

  fun box get_x(): F64 => _x

  fun box get_y(): F64 => _y
  
  fun box distance(point: Point): F64 =>
    let x = point.get_x() - _x
    let y = point.get_y() - _y
    
    F64((x * x) - (y * y)).sqrt()
    
class Box
  let _x1: F64
  let _y1: F64
  let _x2: F64
  let _y2: F64

  new create(x1: F64, y1: F64, x2: F64, y2: F64) =>
    _x1 = x1
    _y1 = y1
    _x2 = x2
    _y2 = y2

  fun box contains(point: Point): Bool =>
    let x = point.get_x()
    let y = point.get_y()

    (_x1 <= x) and (_y1 <= y) and (x <= _x2) and (y <= _y2)

  fun box middle(): Point => 
    recover Point((_x1 + _x2) / 2, (_y1 + _y2) / 2) end
    
class Facility
  let _center: Point
  let _points: SetIs[Point]
  var _distance: F64
  var _max_distance: F64

  new create(center: Point) =>
    _center = center
    _points = SetIs[Point]
    _distance = 0
    _max_distance = 0

  fun ref add(point: Point) =>
    let distance = _center.distance(point)

    if distance > _max_distance then
      _max_distance = distance
    end
    
    _distance = _distance + distance
    _points.add(point)

  fun ref get_total_distance(): F64 => _distance

  fun ref get_number_of_points(): USize => _points.size()

actor Facloc
  new run(args: Command val, env: Env) =>
    let points = args.option("points").u64()
    let size = args.option("grid").u64().f64() 
    let threshold = args.option("alpha").f64() * (F64(2).sqrt() * size)
    let seed = args.option("seed").u64()
    let boundingbox = recover Box(0, 0, size, size) end

    let quadrant = Quadrant(None, Root, consume boundingbox, 
      threshold, 0, recover Array[Point] end, 1, -1, recover Array[Point] end)

    Producer(quadrant, points, size, recover SimpleRand(seed) end)

actor Quadrant
  let _parent: (Quadrant | None)
  let _position: Position
  let _boundingbox: Box val
  let _threshold: F64
  let _depth: U64
  let _local_facilities: Array[Point]
  let _known_facilities: U64
  let _max_depth: I64
  let _customers: Array[Point]
  let _facility: Point
  let _support_customers: Array[Point]
  var _children_facilities: U64
  var _facility_customers: U64
  var _children: (Array[Quadrant] | None)
  var _boundaries: (Array[Box] | None)
  var _total_cost: F64

  new create(
    parent: (Quadrant | None), 
    position: Position, 
    boundingbox: Box iso, 
    threshold: F64,
    depth: U64,
    local_facilities: Array[Point] iso,
    known_facilities: U64,
    max_depth: I64,
    customers: Array[Point] iso) 
  =>
    _parent = parent
    _position = position
    _boundingbox = consume boundingbox
    _threshold = threshold
    _depth = depth
    _local_facilities = consume local_facilities
    _known_facilities = known_facilities
    _max_depth = max_depth
    _customers = consume customers
    
    _facility = _boundingbox.middle()
    _local_facilities.push(_facility)
    _support_customers = Array[Point]
    _children_facilities = 0
    _facility_customers = 0
    _children = None
    _boundaries = None
    _total_cost = 0

    for point in _customers.values() do
      if _boundingbox.contains(point) then
        _add_customer(point)
      end
    end

  fun ref _find_cost(point: Point): F64 =>
    var result = F64.max_value()

    for point' in _local_facilities.values() do
      let distance = point'.distance(point)
      
      if distance < result then
        result = distance
      end
    end

    result

  fun ref _add_customer(point: Point) =>
    _support_customers.push(point)
    _total_cost = _total_cost + _find_cost(point)

  be customer(producer: Producer, at: Point) =>
    None

actor Producer
  let _quadrant: Quadrant
  let _points: U64
  let _size: F64
  let _random: SimpleRand
  var _produced: U64

  new create(quadrant: Quadrant, points: U64, size: F64, random: SimpleRand iso) =>
    _quadrant = quadrant
    _points = points
    _size = size
    _random = consume random
    _produced = 0

    _produce_customer()

  fun ref _produce_customer() =>
    _quadrant.customer(this, PointFactory.random(_random, _size))
    _produced = _produced + 1

  be next() =>
    if _produced < _points then
      _produce_customer()
    end
