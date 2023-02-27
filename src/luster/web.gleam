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
import gleam/io

pub type Context {
  Context(session: Subject(GameState))
}

// TODO: Form params could be stricter to avoid assertions
pub type Request {
  FormRequest(
    method: Method,
    path: String,
    form: Map(String, String),
    // context could be parametrized or optional
    context: Context,
  )
}

pub type Response {
  // template can have implicit status 200
  Template(mime: Mime, template: Template)
  Static(mime: Mime, path: String)
  Redirect(location: Uri)
  Flash(message: String, color: RGB)
  NotFound(message: String)
}

pub fn service(
  request: request.Request(BitString),
) -> repsonse.Response(BitBuilder) {
  assert Ok(subject) = session.start(Nil)
  let context = Context(session: subject)
  // Pass request through middleware to transform request/response
  request
  // If this is a form request we should return a `FormRequest` response
  |> middleware.process_form()
  |> middleware.from_mist_request()
  |> router()
  |> middleware.to_mist_request()
  |> middleware.to_bit_builder()
}

fn router(request: Request) -> Response {
  case request.method, request.path {
    Get, "/" -> arcade.index()
    Put, "/new-battleline" -> arcade.new_battleline(request.context)
    Get, "/error-message" -> arcade.error_message(request.context)

    Get, "/chat" -> chat.index(request)
    Post, "/chat/send-message" -> chat.send_message(request)
    Get, "/chat/click/example" -> chat.click_example(request)
    Get, "/chat/click/lazy" -> chat.click_example_lazy(request)

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
