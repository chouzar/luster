import gleam/int
import gleam/float
import gleam/string
import gleam/list
import gleam/string_builder
import gleam/option.{None, Option, Some}
import luster/web/template.{Template}
import luster/battleline.{Card, Club, Diamond, Heart, Spade}
import gleam/bbmustache.{CompileError}

pub fn render(card: Card) -> Template {
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

  template.new("src/luster/web/battleline/component/card_front.html")
  |> template.args(replace: "suit", with: suit)
  |> template.args(replace: "rank", with: rank)
  |> template.args(replace: "color", with: color)
}
