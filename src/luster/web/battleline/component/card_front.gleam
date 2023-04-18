import gleam/int
import luster/battleline.{Card, Club, Diamond, Heart, Spade}
import luster/web/plant

pub fn new(card: Card) -> plant.Template {
  let suit = case card.suit {
    Spade -> "♠"
    Heart -> "♥"
    Diamond -> "♦"
    Club -> "♣"
  }

  let color = case card.suit {
    Spade -> "blue"
    Heart -> "red"
    Diamond -> "green"
    Club -> "purple"
  }

  let rank = int.to_string(card.rank)

  plant.lay(
    from: "src/luster/web/battleline/component/card_front.html",
    with: [
      #("suit", plant.raw(suit)),
      #("rank", plant.raw(rank)),
      #("color", plant.raw(color)),
    ],
  )
}
