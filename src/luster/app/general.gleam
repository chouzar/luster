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
    |> template.from(["svg_example.html"])
    |> template.render(),
  )
}

pub fn error(_: Request(FormFields)) -> Response(String) {
  response.new(404)
  |> response.set_body("error")
}
