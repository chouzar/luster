import gleam/list
import gleam/string_builder
import luster/web/battleline/component/card_back.{Background}
import luster/battleline.{Card}

pub fn render(deck: List(Card), back: Background) -> String {
  let card_count = case list.length(deck) {
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

  let card = card_back.render(back)

  string_builder.to_string({
    use builder, _times, _index <- repeat(card_count, string_builder.new())
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
