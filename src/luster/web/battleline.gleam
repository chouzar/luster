import gleam/map
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template
import luster/battleline.{GameState, Persia}
import luster/web/battleline/component/turbo_stream.{Append, Update}
import luster/web/battleline/component/card

pub fn index(_: Request(FormFields)) -> Response(String) {
  let state = load("1234567890")

  let draw_pile = card.render_draw_pile(state.deck)

  // TODO: create a layout component
  let body =
    template.new(["src", "luster", "web", "battleline", "component"])
    |> template.from(["index.html"])
    |> template.args(replace: "draw-pile", with: draw_pile)
    |> template.render()

  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(body)
}

pub fn draw_card(req: Request(FormFields)) -> Response(String) {
  assert Ok(_session) = map.get(req.body, "session")
  assert Ok(_player) = map.get(req.body, "player")

  let state = load("1234567890")

  let #(card, state) = battleline.draw_card(state, for: Persia)

  let card = card.render_front(card)
  let draw_pile = card.render_draw_pile(state.deck)

  let body =
    turbo_stream.new()
    |> turbo_stream.add(draw_pile, do: Update, at: "draw-pile")
    |> turbo_stream.add(card, do: Append, at: "player-hand")
    |> turbo_stream.render()

  response.new(200)
  |> response.prepend_header("content-type", mime.turbo_stream)
  |> response.set_body(body)
}

pub fn assets(path: List(String)) -> Response(String) {
  response.new(200)
  |> response.set_body(
    template.new(["src", "luster", "web", "battleline", "assets"])
    |> template.from(path)
    |> template.render(),
  )
}

fn load(_id: String) -> GameState {
  // We load the state from a memory location
  battleline.new_game()
}
