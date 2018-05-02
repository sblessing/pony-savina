use "cli"
use "collections"

primitive TrapezoidConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("trapezoid", "", [
        OptionSpec.u64(
          "pieces",
          "The number of pieces. Defaults to 10000000."
          where short' = 'p', default' = 10000000
        )
        OptionSpec.u64(
          "workers",
          "The number of workers. Defaults to 100."
          where short' = 'w', default' = 100
        )
        OptionSpec.u64(
          "left",
          "The left-end point. Defaults to 1."
          where short' = 'x', default' = 1
        )
        OptionSpec.u64(
          "right",
          "The right-end point. Defaults to 5."
          where short' = 'y', default' = 5
        )
      ]) ?
    end

actor Trapezoid
  new run(args: Command val, env: Env) =>
    let left = args.option("left").u64()
    let right = args.option("right").u64()
    let precision: F64 = ( right - left ).f64() / args.option("pieces").u64().f64()
    
    Master(
      env,
      args.option("workers").u64(),
      left.f64(),
      right.f64(),
      precision
    )

actor Master
  let _env: Env
  var _result_area: F64
  var _workers: U64

  new create(env: Env, workers: U64, left: F64, right: F64, precision: F64) =>
    _env = env
    _workers = workers
    _result_area = 0

    let range: F64 = (right - left).f64() / workers.f64()

    for i in Range[F64](0, workers.f64()) do
      Worker(this, (range * i) + left, left + range, precision)
    end

  be result(area: F64) =>
    _result_area = _result_area + area

    if (_workers = _workers - 1) == 1 then
      _env.out.print("  Area: " + _result_area.string())
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
    let n: U64 = ((right - left) / precision).u64()
    var accumulated_area: F64 = 0.0

    var i: U64 = 0

    while i < n do
      let lx = (i.f64() * precision) + left
      let rx = lx + precision

      let ly = Fx(lx)
      let ry = Fx(rx)

      accumulated_area = accumulated_area + (0.5 * (ly + ry) * precision)

      i = i + 1
    end

    master.result(accumulated_area)