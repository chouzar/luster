import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template
import luster/battleline

pub fn index() -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(
    template.new(["src", "luster", "web", "card_arcade"])
    |> template.from(["index.html"])
    |> template.render(),
  )
}

pub fn new_battleline(context: Context) -> Response(String) {
  let id = new_id()
  let state = battleline.new_game()

  assert Nil =
    context.session
    |> session.set(id, state)

  response.new(303)
  |> response.prepend_header("location", "/battleline/" <> id)
  |> response.set_body("")
}

pub fn inavlid_action() -> Response(String) {
  todo
}

pub fn error_message() -> Response(String) {
  todo
}

pub fn error(_: Request(FormFields)) -> Response(String) {
  response.new(404)
  |> response.set_body("path not available")
}

fn new_id() -> String {
  15
  |> random_bytes()
  |> encode()
  |> proquint()
  |> string.slice(at_index: 6, length: 17)
}

external fn proquint(binary) -> String =
  "Elixir.Proquint" "encode"

external fn random_bytes(seed) -> String =
  "crypto" "strong_rand_bytes"

external fn encode(binary) -> String =
  "base64" "encode"
