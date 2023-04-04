import gleam/int
import luster/battleline.{Card, Club, Diamond, Heart, Spade}
import luster/web/plant.{Layout, Raw, Template}

pub fn new(card: Card) -> Template {
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

  Layout(
    path: "src/luster/web/battleline/component/card_front.html",
    contents: [
      #("suit", Raw(suit)),
      #("rank", Raw(rank)),
      #("color", Raw(color)),
    ],
  )
}
