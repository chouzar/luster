import gleam/map
import gleam/http
import gleam/http/request
import gleam/http/response
import luster/server
import luster/server/mime
import luster/app/chat

pub fn run() -> Nil {
  server.run(8088, handle_request)
}

pub type FormFields =
  map.Map(String, String)

fn handle_request(
  request: request.Request(FormFields),
) -> response.Response(String) {
  case request.method, request.path {
    http.Get, "/" ->
      response.new(200)
      |> response.prepend_header("content-type", mime.html)
      |> response.set_body("hello")

    http.Get, "/chat" -> chat.index(request)

    http.Post, "/chat/send-message" -> chat.send_message(request)

    _, _ ->
      response.new(404)
      |> response.set_body("error")
  }
}
