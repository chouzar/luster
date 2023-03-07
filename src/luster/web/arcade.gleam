import gleam/string
import gleam/map.{Map}
import luster/session
import luster/battleline
import luster/web/template
import luster/web/context.{Context}
import luster/web/payload.{HTML, Redirect, Render, Request, Response}
import gleam/io

pub fn index() -> Response {
  Render(
    mime: HTML,
    document: template.new("src/luster/web/arcade/component")
    |> template.from("index.html")
    |> template.render(),
  )
}

pub fn new_battleline(request: Request(Context)) -> Response {
  let id = new_id()
  let state = battleline.new_game()

  assert Nil = session.set(request.context.session, id, state)

  Redirect(location: "/battleline/" <> id)
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
