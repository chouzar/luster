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
  let context = Context(session_pid: session_pid)

  fn(request: request.Request(BitString)) -> response.Response(BitBuilder) {
    request
    |> middleware.process_form()
    |> middleware.from_mist_request()
    |> router(context)
    |> middleware.into_mist_response()
    |> middleware.to_bit_builder()
  }
}

// TODO: Eventually eliminate all `Request` data passed to controllers
// or eventually add everything to `Request` so we can get request -> resposne controllers
fn router(request: Request, context: Context) -> Response {
  case request.method, request.path_segments {
    Get, [] -> arcade.index()
    Post, ["new-battleline"] -> arcade.new_battleline(context)
    Get, ["battleline", session_id] -> battleline.index(context, session_id)
    Post, ["battleline", session_id, "draw-card"] ->
      battleline.draw_card(request, context, session_id)
    Get, ["assets", ..] -> assets(request)
    _, _ -> error(request)
  }
}

fn assets(request: Request) -> Response {
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

fn error(request: Request) -> Response {
  [
    "Error: Unable to find path",
    "Method: " <> http.method_to_string(request.method),
    "Path: " <> request.path,
  ]
  |> string.join("/n")
  |> io.print()

  NotFound(message: "Page not found")
}
