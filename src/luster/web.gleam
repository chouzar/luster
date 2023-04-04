import gleam/erlang/process.{Subject}
import gleam/bit_builder.{BitBuilder}
import gleam/string
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/http/response
import luster/util
import luster/web/middleware
import luster/web/arcade
import luster/web/battleline
import luster/session.{Message}
import luster/web/plant.{Static}
import luster/web/payload.{CSS, Document, Favicon, In, NotFound, Out}

pub fn service(
  session_pid: Subject(Message),
) -> fn(request.Request(BitString)) -> response.Response(BitBuilder) {
  // Starts 1 instance of the session server

  fn(request: request.Request(BitString)) -> response.Response(BitBuilder) {
    request
    |> middleware.process_form()
    |> middleware.from_mist_request()
    |> router(session_pid)
    |> middleware.into_mist_response()
    |> middleware.to_bit_builder()
  }
}

fn router(payload: In, session_pid: Subject(session.Message)) -> Out {
  let player_id = "Raúl"

  case payload.method, payload.path {
    Get, [] ->
      payload
      |> arcade.index()

    Post, ["new-battleline"] ->
      payload
      |> arcade.new_battleline(session_pid, player_id)

    Get, ["battleline", session_id] ->
      payload
      |> battleline.mount(session_pid, session_id, player_id)

    Post, ["battleline", session_id, "draw-card"] ->
      payload
      |> battleline.draw_card(session_pid, session_id, player_id)

    Get, ["assets", ..] ->
      payload
      |> assets()

    _, _ -> {
      util.report([
        "Error: Unable to find path",
        "Method: " <> http.method_to_string(payload.method),
        "Path: " <> payload.static_path,
      ])

      NotFound(message: "Page not found")
    }
  }
}

fn assets(payload: In) -> Out {
  // TODO: Find a generic way to get shared content.
  case payload.static_path {
    "/assets/battleline/styles.css" ->
      Document(
        mime: CSS,
        template: Static(path: "/src/luster/web/battleline/assets/styles.css"),
      )

    "/assets/battleline/favicon.ico" ->
      Document(
        mime: Favicon,
        template: Static(path: "/src/luster/web/battleline/assets/favicon.ico"),
      )
  }
}

fn flash(_payload: In, _message: String, _color: String) -> Out {
  //[
  //  "Error: Invalid action",
  //  "Method: " <> http.method_to_string(request.method),
  //  "Path: " <> request.static_path,
  //  "Data: Key" <> " key " <> "not found",
  //]
  //|> string.join("/n")
  //|> io.print()

  //Flash(message, color)
  todo
}
