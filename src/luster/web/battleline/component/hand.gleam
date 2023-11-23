import gleam/list
import luster/battleline/pieces.{type Card}
import luster/web/plant
import luster/web/battleline/component/card_front

pub fn new(hand: List(Card)) -> plant.Template {
  plant.many(list.map(hand, card_front.new))
}
