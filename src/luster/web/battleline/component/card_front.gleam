import gleam/int
import luster/battleline/pieces.{Card, Club, Diamond, Heart, Spade}
import luster/web/plant
import nakai
import nakai/html.{Text, div, p}
import nakai/html/attrs

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

  div(
    [attrs.class("card front clouds " <> color)],
    [
      div(
        [attrs.class("upper-left")],
        [p([], [Text(rank)]), p([], [Text(suit)])],
      ),
      div([attrs.class("graphic")], [p([], [Text(suit)])]),
      div(
        [attrs.class("bottom-right")],
        [p([], [Text(rank)]), p([], [Text(suit)])],
      ),
    ],
  )
  |> nakai.to_inline_string()
  |> plant.raw()
}
