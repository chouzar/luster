import gleam/int
import gleam/list
import gleam/string_builder
import luster/web/battleline/component/card_back.{Background}
import luster/battleline.{Card}

pub fn render(deck: List(Card), back: Background) -> String {
  assert Ok(card_count) = int.divide(list.length(deck), 12)

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
