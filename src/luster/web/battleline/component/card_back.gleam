import gleam/int
import gleam/float
import gleam/string
import gleam/list
import gleam/string_builder
import gleam/option.{None, Option, Some}
import luster/web/template
import luster/battleline.{Card, Club, Diamond, Heart, Spade}

pub type Background {
  Clouds
  Diamonds
}

pub fn render(back: Background) {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  template.new("src/luster/web/battleline/component")
  |> template.from("card_back.html")
  |> template.args(replace: "background", with: background)
  |> template.render()
}
