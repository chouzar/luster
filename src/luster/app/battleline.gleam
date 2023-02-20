import gleam/map
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template
import luster/battleline.{GameState, Persia}
import luster/app/battleline/component/turbo_stream.{Append}
import luster/app/battleline/component/card

pub fn index(_: Request(FormFields)) -> Response(String) {
  let state = load("1234567890")

  let draw_pile = card.render_draw_pile(state.deck)

  // TODO: create a layout component
  let body =
    template.new(["src", "luster", "app", "battleline", "component"])
    |> template.from(["index.html"])
    |> template.args(replace: "card-draw-pile", with: draw_pile)
    |> template.render()

  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(body)
}

pub fn draw_card(req: Request(FormFields)) -> Response(String) {
  assert Ok(_session) = map.get(req.body, "session")
  assert Ok(_player) = map.get(req.body, "player")

  let state = load("1234567890")

  let #(card, _state) = battleline.draw_card(state, for: Persia)

  let card = card.render_front(card)
  let body = turbo_stream.render(Append, "player-hand", card)

  response.new(200)
  |> response.prepend_header("content-type", mime.turbo_stream)
  |> response.set_body(body)
}

pub fn favicon(_: Request(FormFields)) -> Response(String) {
  response.new(200)
  |> response.set_body(
    template.new(["src", "luster", "app", "battleline", "component"])
    |> template.from(["favicon.ico"])
    |> template.render(),
  )
}

pub fn css(_: Request(FormFields)) -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", mime.css)
  |> response.set_body(
    template.new(["src", "luster", "app", "battleline", "component"])
    |> template.from(["styles.css"])
    |> template.render(),
  )
}

fn load(_id: String) -> GameState {
  // We load the state from a memory location
  battleline.new_game()
}
