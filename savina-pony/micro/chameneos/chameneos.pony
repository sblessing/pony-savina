use "collections"
use "../../util"

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

class iso Chameneos is AsyncActorBenchmark
  let _meetings: U64
  let _chameneos: U64

  new iso create(chameneos: U64, meetings: U64) =>
    _meetings = meetings
    _chameneos = chameneos
  
  fun box apply(c: AsyncBenchmarkCompletion, last: Bool) =>
    Mall(c, _meetings, _chameneos)
  
  fun tag name(): String => "Chameneos"

actor Mall
  let _bench: AsyncBenchmarkCompletion
  let _chameneos: U64
  var _faded: U64
  var _meetings: U64
  var _sum: U64
  var _waiting: (Chameneo | None)

  new create(c:AsyncBenchmarkCompletion, meetings': U64, chameneos: U64) =>
    _bench = c
    _chameneos = chameneos
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

    if _faded == _chameneos then
      _bench.complete()
    end
  
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