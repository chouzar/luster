import mist
import gleam/bit_builder
import gleam/string
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{Request}
import gleam/http/response

pub fn main() -> Nil {
  assert Ok(Nil) = mist.run_service(8088, router, max_body_limit: 400_000)
  process.sleep_forever()
}

fn router(payload) {
  let Request(method, _headers, body, _scheme, _host, _port, path, _query) =
    payload

  case method, path {
    Get, "/" ->
      response.new(200)
      |> response.set_body(template(["templates", "svg_example.html"]))

    Get, "/chat" ->
      response.new(200)
      |> response.prepend_header("content-type", "text/html; charset=utf-8")
      |> response.set_body(template(["templates", "chat.html"]))

    Post, "/chat/send-message" ->
      response.new(200)
      |> response.prepend_header("content-type", "text/vnd.turbo-stream.html; charset=utf-8")
      |> response.set_body(template(["templates", "turbo_stream", "message.html"]))

    _, _ ->
      response.new(404)
      |> response.set_body(bit_builder.from_bit_string(<<"error":utf8>>))
  }
}

fn template(file_path: List(String)) {
  assert Ok(template) =
    [root(), ..file_path]
    |> path()
    |> read()

  bit_builder.from_string(template)
}

fn path(path: List(String)) -> String {
  string.join(path, with: "/")
}

fn root() -> String {
  string.join([cwd(), "src"], with: "/")
}

external fn cwd() -> String =
  "Elixir.File" "cwd!"

external fn read(path: String) -> Result(String, error) =
  "Elixir.File" "read"
