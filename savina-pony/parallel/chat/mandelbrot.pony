use "cli"
use "collections"

actor MandelbrotWorker
  new create(coordinator: Mandelbrot, x: USize, y: USize, width: USize,
    iterations: USize, limit: F32, real: Array[F32] val,
    imaginary: Array[F32] val)
  =>
    var view: Array[U8] iso =
      recover
        Array[U8]((y - x) * (width >> 3))
      end

    let group_r = Array[F32].>undefined(8)
    let group_i = Array[F32].>undefined(8)

    var row = x

    try
      while row < y do
        let prefetch_i = imaginary(row)?

        var col: USize = 0

        while col < width do
          var j: USize = 0

          while j < 8 do
            group_r.update(j, real(col + j)?)?
            group_i.update(j, prefetch_i)?
            j = j + 1
          end

          var bitmap: U8 = 0xFF
          var n = iterations

          repeat
            var mask: U8 = 0x80
            var k: USize = 0

            while k < 8 do
              let r = group_r(k)?
              let i = group_i(k)?

              group_r.update(k, ((r * r) - (i * i)) + real(col + k)?)?
              group_i.update(k, (2.0 * r * i) + prefetch_i)?

              if ((r * r) + (i * i)) > limit then
                bitmap = bitmap and not mask
              end

              mask = mask >> 1
              k = k + 1
            end
          until (bitmap == 0) or ((n = n - 1) == 1) end

          view.push(bitmap)

          col = col + 8
        end
        row = row + 1
      end

      coordinator.report(x * (width >> 3), consume view)
    end

class val MandelbrotConfig
  let iterations: USize
  let limit: F32
  let chunks: USize
  let width: USize

  new val default() =>
    iterations = 50
    limit = 4.0
    chunks = 16
    width = 16000

actor Mandelbrot
  let c: MandelbrotConfig
  let chat: Chat
  var actors: USize = 0
  var header: USize = 0
  var real: Array[F32] val = recover Array[F32] end
  var imaginary: Array[F32] val = recover Array[F32] end

  new create(chat': Chat) =>
    chat = chat'
    c = MandelbrotConfig.default()
     
    let length = c.width
    let recip_width = 2.0 / c.width.f32()

    var r = recover Array[F32](length) end
    var i = recover Array[F32](length) end

    for j in Range(0, c.width) do
      r.push((recip_width * j.f32()) - 1.5)
      i.push((recip_width * j.f32()) - 1.0)
    end

    real = consume r
    imaginary = consume i

    spawn_actors()
    
  be report(offset: USize, pixels: Array[U8] val) =>
    None //chat.post(pixels)
    
  fun ref spawn_actors() =>
    actors = ((c.width + (c.chunks - 1)) / c.chunks)
    var rest = c.width % c.chunks
    if rest == 0 then rest = c.chunks end

    var x: USize = 0
    var y: USize = 0

    for i in Range(0, actors - 1) do
      x = i * c.chunks
      y = x + c.chunks
      MandelbrotWorker(this, x, y, c.width, c.iterations, c.limit, real, imaginary)
    end

    MandelbrotWorker(this, y, y + rest, c.width, c.iterations, c.limit, real,
      imaginary)