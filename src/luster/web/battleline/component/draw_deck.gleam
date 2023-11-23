import gleam/list
import luster/web/plant
import luster/web/battleline/component/card_back.{type Background}

pub fn new(back: Background, size: Int) -> plant.Template {
  let count = case size {
    x if x > 48 -> 13
    x if x > 44 -> 12
    x if x > 40 -> 11
    x if x > 36 -> 10
    x if x > 32 -> 09
    x if x > 28 -> 08
    x if x > 24 -> 07
    x if x > 20 -> 06
    x if x > 16 -> 05
    x if x > 12 -> 04
    x if x > 08 -> 03
    x if x > 04 -> 02
    x if x > 00 -> 01
    0 -> 0
  }

  let card = card_back.new(back)

  plant.many(list.repeat(card, count))
}
