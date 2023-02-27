import gleam/string
import gleam/list
import gleam/map
import gleam/bit_string
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template
import luster/battleline.{GameState, Persia}
import luster/web/context.{Context}
import luster/web/battleline/component/turbo_stream.{Append, Update}
import luster/web/battleline/component/card
import luster/web/session

pub fn new_game(context: Context) -> Nil {
  context.session
  |> session.set(new_id(), battleline.new_game())
}

pub fn update(context: Context, id: String, state: GameState) -> Nil {
  context.session
  |> session.set(id, state)
}

pub fn get(context: Context, id: String) -> GameState {
  context.session
  |> session.get(id)
}

fn new_id() -> String {
  15
  |> random_bytes()
  |> encode()
}

external fn random_bytes(seed) -> String =
  "crypto" "strong_rand_bytes"

external fn encode(binary) -> String =
  "base64" "encode"
