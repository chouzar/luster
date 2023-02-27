import gleam/int
import gleam/float
import gleam/string
import gleam/list
import gleam/string_builder
import gleam/option.{None, Option, Some}
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

  template.new(["src", "luster", "web", "battleline", "component"])
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
  render_back_offset(back, None)
}

pub fn render_draw_pile(deck: List(Card)) -> String {
  render_pile(deck, Clouds)
}

pub fn render_special_draw_pile(deck: List(Card)) -> String {
  render_pile(deck, Spades)
}

fn render_pile(deck: List(Card), back: Background) -> String {
   assert Ok(cards) = int.divide(list.length(deck) + 2, 3)

  string_builder.to_string({
    use builder, _times, index <- repeat(cards, string_builder.new())
    let offset = index * 1
    let card = render_back_offset(back, Some(#(offset, offset)))
    string_builder.append(builder, card)
  })
}

fn render_back_offset(back: Background, pos_offset: Option(#(Int, Int))) {
  let background = case back {
    Clouds -> "clouds"
    Spades -> "spades"
  }

  let styles = case pos_offset {
    None -> ""
    Some(#(x, y)) ->
      string.join(
        [
          "bottom:",
          int.to_string(y),
          "px;",
          "right:",
          int.to_string(x),
          "px;",
        ],
        "",
      )
  }

  template.new(["src", "luster", "web", "battleline", "component"])
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
