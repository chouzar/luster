import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/string
import gleam/list
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{Request}
import gleam/http/response
import gleam/bbmustache as mustache
import mist
import gleam/io

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
      |> response.set_body(render(["templates", "svg_example.html"], []))

    Get, "/chat" ->
      response.new(200)
      |> response.prepend_header("content-type", "text/html; charset=utf-8")
      |> response.set_body(render(["templates", "chat.html"], []))

    Post, "/chat/send-message" -> {
      let <<"message=":utf8, message:binary>> = body

      assert Ok(message) =
       message
        |> bit_string.to_string()

      response.new(200)
      |> response.prepend_header(
        "content-type",
        "text/vnd.turbo-stream.html; charset=utf-8",
      )
      |> response.set_body(render(
        ["templates", "turbo_stream", "message.html"],
        [#("message", message)],
      ))
    }

    _, _ ->
      response.new(404)
      |> response.set_body(bit_builder.from_bit_string(<<"error":utf8>>))
  }
}

pub fn render(
  file_path: List(String),
  params: List(#(String, String)),
) -> BitBuilder {
  assert Ok(template) =
    file_path
    |> template()
    |> mustache.compile()

  let params =
    params
    |> list.map(fn(param) { #(param.0, mustache.string(param.1)) })

  template
  |> mustache.render(params)
  |> bit_builder.from_string()
}

pub fn template(file_path: List(String)) -> String {
  assert Ok(template) =
    [root(), ..file_path]
    |> path()
    |> read()

  template
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
