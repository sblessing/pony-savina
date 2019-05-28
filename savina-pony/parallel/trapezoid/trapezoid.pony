use "collections"
use "../../util"

class iso Trapezoid is AsyncActorBenchmark
  let _pieces: U64
  let _workers: U64
  let _left: U64
  let _right: U64
  let _precision: F64

  new iso create(pieces: U64, workers: U64, left: U64, right: U64) =>
    _pieces = pieces
    _workers = workers
    _left = left
    _right = right
    _precision = ( right - left ).f64() / _pieces.f64()
  
  fun box apply(c: AsyncBenchmarkCompletion) =>    
    Master(
      c,
      _workers,
      _left.f64(),
      _right.f64(),
      _precision
    )
  
  fun tag name(): String => "Trapezoid"

actor Master
  let _bench: AsyncBenchmarkCompletion
  var _result_area: F64
  var _workers: U64

  new create(c: AsyncBenchmarkCompletion, workers: U64, left: F64, right: F64, precision: F64) =>
    _bench = c
    _workers = workers
    _result_area = 0

    let range: F64 = (right - left).f64() / workers.f64()

    for i in Range[F64](0, workers.f64()) do
      let left' = (range * i) + left
      Worker(this, left', left' + range, precision)
    end

  be result(area: F64) =>
    _result_area = _result_area + area

    if (_workers = _workers - 1) == 1 then
      _bench.complete()
    end

primitive Fx
  fun apply(x: F64): F64 =>
    let a = (x.pow(3) - 1).sin()
    let b = x + 1
    let c = a / b
    let d = (F64(2 * x).sqrt().exp() + 1).sqrt()

    c * d

actor Worker
  new create(master: Master, left: F64, right: F64, precision: F64) =>
    let n: F64 = ((right - left) / precision).f64()
    var accumulated_area: F64 = 0.0

    var i: F64 = 0

    while i < n do
      let lx = (i.f64() * precision) + left
      let rx = lx + precision

      let ly = Fx(lx)
      let ry = Fx(rx)

      accumulated_area = accumulated_area + (0.5 * (ly + ry) * precision)

      i = i + 1
    end

    master.result(accumulated_area)