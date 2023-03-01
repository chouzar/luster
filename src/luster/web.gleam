import gleam/map.{Map}
import gleam/erlang/process.{Subject}
import gleam/http.{Get, Method, Post, Put}
import gleam/http/request
import gleam/http/response.{Response}
import luster/server
import luster/server/middleware
import luster/web/context.{Context}
import luster/web/arcade
import luster/web/chat
import luster/web/battleline.{GameState}
import luster/web/session
import luster/web/payload
import gleam/io

pub type Context {
  Context(session: Subject(GameState))
}

pub fn service(
  request: request.Request(BitString),
) -> repsonse.Response(BitBuilder) {
  assert Ok(subject) = session.start(Nil)
  let context = Context(session: subject)

  request
  |> middleware.process_form()
  |> middleware.from_mist_request(context)
  |> router()
  |> middleware.into_mist_response()
  |> middleware.to_bit_builder()
}

fn router(request: Request) -> Response {
  case request.method, request.path {
    Get, "/" -> arcade.index()
    Put, "/new-battleline" -> arcade.new_battleline(request.context)
    Get, "/error-message" -> arcade.error_message(request.context)

    method, _path ->
      case method, request.path_segments(request) {
        //Put, ["battleline", "new"] -> battleline.new(request, context)
        Get, ["battleline", "new"] -> battleline.new(request, context)

        Get, ["battleline", id] -> battleline.index(request, context, id)

        Post, ["battleline", id, "draw-card"] ->
          battleline.draw_card(request, context, id)

        Get, ["battleline", "assets", ..path] -> battleline.assets(path)
      }

    _, _ -> arcade.error(request)
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
