import gleam/int
import gleam/list
import gleam/string_builder
import luster/web/battleline/component/card_back.{Background}
import luster/battleline.{Card, GameState}
import luster/web/template

pub fn render(state: GameState) -> String {
  let odd_pile = pile(state.deck, card_back.Spades)
  let draw_pile = pile(state.deck, card_back.Clouds)

  template.new("src/luster/web/battleline/component")
  |> template.from("board.html")
  |> template.args(replace: "odd-pile", with: odd_pile)
  |> template.args(replace: "draw-pile", with: draw_pile)
  |> template.render()
}

fn pile(deck: List(Card), back: Background) -> String {
  assert Ok(card_count) = int.divide(list.length(deck), 10)

  let card = card_back.render(back)

  string_builder.to_string({
    use builder, _times, index <- repeat(card_count, string_builder.new())
    string_builder.append(builder, card)
  })
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
