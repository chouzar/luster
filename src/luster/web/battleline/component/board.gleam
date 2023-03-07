import gleam/int
import gleam/list
import gleam/string_builder
import luster/web/battleline/component/card_back
import luster/web/battleline/component/card_pile
import luster/battleline.{Card, GameState}
import luster/web/template

pub fn render(state: GameState, session_id: String) -> String {
  let odd_pile = card_pile.render(state.deck, card_back.Diamonds)
  let draw_pile = card_pile.render(state.deck, card_back.Clouds)

  template.new("src/luster/web/battleline/component")
  |> template.from("board.html")
  |> template.args(replace: "odd-pile", with: odd_pile)
  |> template.args(replace: "draw-pile", with: draw_pile)
  |> template.args(replace: "session-id", with: session_id)
  |> template.render()
}
