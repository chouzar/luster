import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{Request}
import gleam/http/response
import mist
import luster/template

// Add "server" module
// Add middleware "response" module
// Add a "template" module and type

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
      |> response.set_body(render(from: ["svg_example.html"], with: []))

    Get, "/chat" ->
      response.new(200)
      |> response.prepend_header("content-type", "text/html; charset=utf-8")
      |> response.set_body(render(from: ["chat.html"], with: []))

    Post, "/chat/send-message" -> {
      let <<"message=":utf8, message:binary>> = body
      assert Ok(message) = bit_string.to_string(message)

      response.new(200)
      |> response.prepend_header(
        "content-type",
        "text/vnd.turbo-stream.html; charset=utf-8",
      )
      |> response.set_body(render(
        from: ["turbo_stream", "message.html"],
        with: [#("message", message)],
      ))
    }

    _, _ ->
      response.new(404)
      |> response.set_body(bit_builder.from_bit_string(<<"error":utf8>>))
  }
}

fn render(
  from path: List(String),
  with params: List(#(String, String)),
) -> BitBuilder {
  case params {
    [] ->
      template.new(["html"])
      |> template.from(path)
      |> template.render()
      |> bit_builder.from_string()

    [_, ..] ->
      template.new(["html"])
      |> template.from(path)
      |> template.with(params)
      |> template.render()
      |> bit_builder.from_string()
  }
}
