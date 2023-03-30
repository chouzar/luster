import gleam/list
import luster/battleline.{Card}
import luster/web/lay.{Many, Template}
import luster/web/battleline/component/card_back.{Background}

pub fn new(back: Background, deck: List(Card)) -> Template {
  let count = case list.length(deck) {
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

  Many(contents: list.repeat(card, count))
}
