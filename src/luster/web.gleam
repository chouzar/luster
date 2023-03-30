//// Adds 1 new id, gamestate to the session

import gleam/io
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
import luster/web/payload.{
  CSS, Favicon, Flash, NotFound, Request, Response, Static,
}

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

// TODO: Eventually eliminate all `Request` data passed to controllers
// or eventually add everything to `Request` so we can get request -> resposne controllers
fn router(request: Request, session_pid: Subject(session.Message)) -> Response {
  let player_id = "Raúl"
  let _flash_error = fn(message) { flash(request, message, "red") }

  case request.method, request.path {
    Get, [] ->
      request
      |> arcade.index()

    Post, ["new-battleline"] ->
      request
      |> arcade.new_battleline(session_pid, player_id)

    Get, ["battleline", session_id] ->
      request
      |> battleline.mount(session_pid, session_id, player_id)

    Post, ["battleline", session_id, "draw-card"] ->
      request
      |> battleline.draw_card(session_pid, session_id, player_id)

    Get, ["assets", ..] ->
      request
      |> assets()

    _, _ -> {
      util.report([
        "Error: Unable to find path",
        "Method: " <> http.method_to_string(request.method),
        "Path: " <> request.static_path,
      ])

      NotFound(message: "Page not found")
    }
  }
}

fn assets(request: Request) -> Response {
  // TODO: Find a generic way to do this.
  case request.static_path {
    "/assets/battleline/styles.css" ->
      Static(mime: CSS, path: "/src/luster/web/battleline/assets/styles.css")

    "/assets/battleline/favicon.ico" ->
      Static(
        mime: Favicon,
        path: "/src/luster/web/battleline/assets/favicon.ico",
      )
  }
}

fn flash(request: Request, message: String, color: String) -> Response {
  [
    "Error: Invalid action",
    "Method: " <> http.method_to_string(request.method),
    "Path: " <> request.static_path,
    "Data: Key" <> " key " <> "not found",
  ]
  |> string.join("/n")
  |> io.print()

  Flash(message, color)
}
// TODO: Build a validator module for maps
// x-spec
// Can be changeset like and based on predicates >-> Accumulates result errors
// If everything passes
// A last parameter could be used to map into a constructor record >-> Accumulates
//   This last parameter could be validated at compile time by using the dynamic type
//fn validate(
//  form: Map(String, String),
//  keys: List(String),
//) -> Result(List(String), Nil) {
//  keys
//  |> list.map(fn(key) { map.get(form, key) })
//  |> result.all()
//}
