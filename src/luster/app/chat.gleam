import gleam/map.{Map}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template

const template_path = ["html", "chat"]

pub fn index(_: Request(FormFields)) -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(
    template.new(template_path)
    |> template.from(["chat.html"])
    |> template.render(),
  )
}

pub fn send_message(req: Request(FormFields)) -> Response(String) {
  assert Ok(message) = map.get(req.body, "message")

  response.new(200)
  |> response.prepend_header("content-type", mime.turbo_stream)
  |> response.set_body(
    template.new(template_path)
    |> template.from(["turbo_stream", "message.html"])
    |> template.args(replace: "message", with: message)
    |> template.render(),
  )
}

pub fn click_example(_) {
  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(
    template.new(template_path)
    |> template.from(["click-example.html"])
    |> template.render(),
  )
}

pub fn click_example_lazy(_) {
  process_sleep(3000)

  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(
    template.new(template_path)
    |> template.from(["click-example-lazy.html"])
    |> template.render(),
  )
}

external fn process_sleep(time: Int) -> Nil =
  "Elixir.Process" "sleep"
