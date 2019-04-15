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
  fun random(seed: U64, size: U64): Point =>
    let r = SimpleRand(seed)
    let x = r.nextDouble() * size.f64()
    let y = r.nextDouble() * size.f64()

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

class val Point is Stringable
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

  fun box string(): String iso^ =>
    let x = Format.float[F64](_x where prec = 2, fmt = FormatFix)
    let y = Format.float[F64](_y where prec = 2, fmt = FormatFix)

    ("(" + x.string() + ", " + y.string() + ")").string() 
    
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

  fun ref contains(point: Point): Bool =>
    let x = point.get_x()
    let y = point.get_y()

    (_x1 <= x) and (_y1 <= y) and (x <= _x2) and (y <= _y2)

  fun ref middle(): Point => 
    recover Point((_x1 + _x2) / 2, (_y1 + _y2) / 2) end
    
class Facility is Stringable
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

  fun box string(): String iso^ =>
    ("Facility{center: " + _center.string() + ", distance: " + _distance.string() + ", num-pts: " + _points.size().string() + "}").string()
  

actor Facloc
  new run(args: Command val, env: Env) =>
    None