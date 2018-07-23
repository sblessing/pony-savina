primitive HalfEven

type RoundMode is HalfEven

class BigDecimal
  new create() => None                                //TODO
  new from[B: (Number & Real[B] val) = U64](a: B) => None   //TODO
  fun shift_left(places: U64) => None                 //TODO
  fun gt(that: box->BigDecimal): Bool => true         //TODO
  fun add(that: BigDecimal): BigDecimal => BigDecimal //TODO
  fun sub(that: BigDecimal): BigDecimal => BigDecimal //TODO
  fun divide(by: BigDecimal, scale: U64, mode: RoundMode): BigDecimal => BigDecimal //TODO
  fun pow(exp: U64): BigDecimal => BigDecimal         //TODO
  