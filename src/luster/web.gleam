//// Adds 1 new id, gamestate to the session

import gleam/io
import gleam/erlang/process.{Subject}
import gleam/bit_builder.{BitBuilder}
import gleam/string
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/http/response
import luster/web/middleware
import luster/web/arcade
import luster/web/battleline
import luster/web/context.{Context}
import luster/session.{Message}
import luster/web/payload.{CSS, Favicon, NotFound, Request, Response, Static}

pub fn service(
  session_pid: Subject(Message),
) -> fn(request.Request(BitString)) -> response.Response(BitBuilder) {
  // Starts 1 instance of the session server
  let context = Context(session: session_pid)

  fn(request: request.Request(BitString)) -> response.Response(BitBuilder) {
    request
    |> middleware.process_form()
    |> middleware.from_mist_request(context)
    |> router()
    |> middleware.into_mist_response()
    |> middleware.to_bit_builder()
  }
}

fn router(request: Request(Context)) -> Response {
  case request.method, request.path_segments {
    Get, [] -> arcade.index()
    Post, ["new-battleline"] -> arcade.new_battleline(request)
    Get, ["battleline", session_id] -> battleline.index(request, session_id)
    Post, ["battleline", session_id, "draw-card"] ->
      battleline.draw_card(request, session_id)
    Get, ["assets", ..] -> assets(request)
    _, _ -> error(request)
  }
}

fn assets(request: Request(Context)) -> Response {
  // TODO: Find a generic way to do this.
  case request.path {
    "/assets/battleline/styles.css" ->
      Static(
        mime: CSS,
        path: "/src/luster/web/battleline/assets",
        file: "styles.css",
      )

    "/assets/battleline/favicon.ico" ->
      Static(
        mime: Favicon,
        path: "/src/luster/web/battleline/assets",
        file: "favicon.ico",
      )
  }
}

fn error(request: Request(Context)) -> Response {
  [
    "Error: Unable to find path",
    "Method: " <> http.method_to_string(request.method),
    "Path: " <> request.path,
  ]
  |> string.join("/n")
  |> io.print()

  NotFound(message: "Page not found")
}
