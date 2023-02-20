import gleam/int
import gleam/float
import gleam/string
import gleam/list
import gleam/string_builder
import luster/server/template
import luster/battleline.{Card, Club, Diamond, Heart, Spade}

// TODO: Model also the back card

pub type Background {
  Clouds
  Spades
}

pub fn render_front(card: Card) -> String {
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

  template.new(["src", "luster", "app", "battleline", "component"])
  |> template.from(["card_front.html"])
  |> template.args(replace: "suit", with: suit)
  |> template.args(replace: "rank", with: rank)
  |> template.args(replace: "color", with: color)
  |> template.render()
}

pub fn render_hand_front(hand: List(Card)) -> String {
  string_builder.to_string({
    use builder, card <- list.fold(hand, string_builder.new())
    let card = render_front(card)
    string_builder.append(builder, card)
  })
}

pub fn render_back(back: Background) {
  render_back_offset(back, #(0.0, 0.0))
}

pub fn render_draw_pile(deck: List(Card)) -> String {
  render_pile(deck, Clouds)
}

pub fn render_special_draw_pile(deck: List(Card)) -> String {
  render_pile(deck, Spades)
}

fn render_pile(deck: List(Card), back: Background) {
  let pixels = 12.0
  let card_count = list.length(deck)
  assert Ok(step) = float.divide(pixels, int.to_float(card_count))

  string_builder.to_string({
    use builder, _times, index <- repeat(card_count, string_builder.new())
    let index = int.to_float(index)
    let offset = float.multiply(index, step)
    let card = render_back_offset(back, #(offset, offset))
    string_builder.append(builder, card)
  })
}

fn render_back_offset(back: Background, position_offset: #(Float, Float)) {
  let background = case back {
    Clouds -> "clouds"
    Spades -> "spades"
  }

  let styles = case position_offset {
    #(0.0, 0.0) -> ""
    #(x, y) ->
      string.join(
        [
          "bottom:",
          float.to_string(y),
          "px;",
          "right:",
          float.to_string(x),
          "px;",
        ],
        "",
      )
  }

  template.new(["src", "luster", "app", "battleline", "component"])
  |> template.from(["card_back.html"])
  |> template.args(replace: "background", with: background)
  |> template.args(replace: "styles", with: styles)
  |> template.render()
}

fn repeat(times: Int, acc: acc, fun: fn(acc, Int, Int) -> acc) -> acc {
  repeat_index(times, 0, acc, fun)
}

fn repeat_index(
  times: Int,
  index: Int,
  acc: acc,
  fun: fn(acc, Int, Int) -> acc,
) -> acc {
  case times {
    times if times > 0 ->
      repeat_index(times - 1, index + 1, fun(acc, times, index), fun)
    0 -> acc
  }
}
