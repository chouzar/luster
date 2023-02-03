import mist
import gleam/bit_builder
import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request.{Request}
import gleam/http/response

pub fn main() -> Nil {
  assert Ok(Nil) = mist.run_service(8088, router, max_body_limit: 400_000)
  process.sleep_forever()
}

fn router(request) {
  let Request(method, _headers, _body, _scheme, _host, _port, path, _query) =
    request

  case method, path {
    Get, "/" ->
      response.new(200)
      |> response.set_body(bit_builder.from_bit_string(<<"Hello!":utf8>>))

    _, _ ->
      response.new(404)
      |> response.set_body(bit_builder.from_bit_string(<<"error":utf8>>))
  }
}
