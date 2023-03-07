//// Adds 1 new id, gamestate to the session

import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/erlang/process.{Subject}
import gleam/http.{Get, Method, Post, Put}
import gleam/http/request
import gleam/http/response
import luster/web/middleware
import luster/web/arcade
import luster/web/battleline
import luster/web/battleline/context.{Context}
import luster/session
import luster/web/payload.{Request, Response}
import gleam/io

pub fn service(
  request: request.Request(BitString),
) -> response.Response(BitBuilder) {
  // Starts 1 instance of the session server
  assert Ok(subject) = session.start(Nil)
  let context = Context(session: subject)

  request
  |> middleware.process_form()
  |> middleware.from_mist_request(context)
  |> router()
  |> middleware.into_mist_response()
  |> middleware.to_bit_builder()
}

fn router(request: Request(Context)) -> Response {
  case request.method, request.path {
    //Get, [] -> arcade.index()
    //Put, ["new-battleline"] -> arcade.new_battleline(request.context)
    //Get, ["error-message"] -> arcade.error_message(request.context)
    //Put, ["battleline", "new"] -> battleline.new(request, context)
    Get, ["battleline", session_id] -> battleline.index(request, session_id)

    //Post, ["battleline", id, "draw-card"] ->
    //  battleline.draw_card(request, context, id)
    //Get, ["battleline", "assets", ..path] -> battleline.assets(path)
    //_, _ -> arcade.error(request)
    _, _ -> battleline.index(request, "")
  }
}
// Or Create a Context type with more info
// method
// path
// body_params
// path_params
//   Maybe a small engine that computes this
// session
// custom assign key value place
// mist_service info

//fn extract_url_data(req: Request(Map(String, String))) -> Request(Map(String, String)) {
// request.map(req, fn(body) {
//  
// })
//}
