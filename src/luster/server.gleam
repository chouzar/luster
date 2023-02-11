import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import mist
import luster/server/middleware

pub fn run(
  port: Int,
  handler: fn(Request(Map(String, String))) -> Response(String),
) -> Nil {
  let service: fn(Request(BitString)) -> Response(BitBuilder) = fn(request) {
    request
    |> middleware.process_form()
    |> handler()
    |> middleware.to_bit_builder()
  }

  // launch server
  assert Ok(Nil) = mist.run_service(port, service, max_body_limit: 400_000)
  process.sleep_forever()
}
