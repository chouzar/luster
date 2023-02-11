import gleam/map.{Map}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template

pub fn index(_: Request(FormFields)) -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(
    template.new(["html"])
    |> template.from(["chat.html"])
    |> template.render(),
  )
}

pub fn send_message(req: Request(FormFields)) -> Response(String) {
  assert Ok(message) = map.get(req.body, "message")

  response.new(200)
  |> response.prepend_header("content-type", mime.turbo_stream)
  |> response.set_body(
    template.new(["html"])
    |> template.from(["turbo_stream", "message.html"])
    |> template.with([#("message", message)])
    |> template.render(),
  )
}
