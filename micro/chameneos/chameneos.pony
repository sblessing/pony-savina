use "cli"
use "collections"

primitive ChameneosConfig
  fun val apply(): CommandSpec iso^ ? =>
    recover
      CommandSpec.leaf("chameneos", "", [
        OptionSpec.u64(
          "chameneos",
          "The number of chameneos. Defaults to 100."
          where short' = 'c', default' = 100
        )
        OptionSpec.u64(
          "meetings",
          "The number meetings. Defaults to 200000."
          where short' = 'm', default' = 200000
        )
      ]) ?
    end

primitive Red
primitive Yellow
primitive Blue
primitive Faded

type ChameneoColor is
  ( Red
  | Yellow
  | Blue
  | Faded
  | None
  )

primitive ColorComplement
  fun apply(color: ChameneoColor, other: ChameneoColor): ChameneoColor =>
    match (color, other)
    | (Faded, _) => Faded
    | (_, Faded) => Faded
    | (Red, Red) => Red
    | (Red, Yellow) => Blue
    | (Red, Blue) => Yellow
    | (Yellow, Red) => Blue
    | (Yellow, Yellow) => Yellow
    | (Yellow, Blue) => Red
    | (Blue, Red) => Yellow
    | (Blue, Yellow) => Red
    | (Blue, Blue) => Blue
    end

primitive ColorFactory
  fun apply(index: U64): ChameneoColor =>
    match index
    | 0 => Red
    | 1 => Yellow
    | 2 => Blue
    else
      None
    end

actor Chameneos
  new run(args: Command val, env: Env) =>
    Mall(args.option("meetings").u64(), args.option("chameneos").u64())

actor Mall
  var _faded: U64
  var _meetings: U64
  var _sum: U64
  var _waiting: (Chameneo | None)

  new create(meetings': U64, chameneos: U64) =>
    _faded = 0
    _sum = 0
    _meetings = meetings'
    _waiting = None

    for i in Range[U64](0, chameneos) do
      Chameneo(this, ColorFactory(i % 3))
    end

  be meetings(count: U64) =>
    _faded = _faded + 1
    _sum = _sum + count
  
  be meet(approaching: Chameneo, color: ChameneoColor) =>
    if _meetings > 0 then
      _waiting = 
        match _waiting
        | None => approaching
        | let chameneo: Chameneo =>
          _meetings = _meetings - 1
          chameneo.meet(approaching, color)
          None
        end
    else
      approaching.report()
    end

actor Chameneo
  let _mall : Mall
  var _color: ChameneoColor
  var _meetings: U64

  new create(mall: Mall, color: ChameneoColor) =>
    _mall = mall
    _color = color
    _meetings = 0
    _mall.meet(this, color)

  be meet(approaching: Chameneo, color: ChameneoColor) =>
    _color = ColorComplement(_color, color)
    _meetings = _meetings + 1
    approaching.change(_color)
    _mall.meet(this, _color)
 
  be change(color: ChameneoColor) =>
    _color = color
    _meetings = _meetings + 1
    _mall.meet(this, _color)

  be report() =>
    _mall.meetings(_meetings)
    _color = Faded