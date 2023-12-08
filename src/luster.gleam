//import gleam/otp/supervisor
import gleam/erlang/process
import luster/web
import luster/session
import luster/web/middleware
import gleam/http/request
import gleam/http/response
import mist

//import gleam/erlang/process

// TODO: Create a web, games and luster/runtime contexts
// TODO: Add supervision tree

pub fn main() -> Nil {
  // TODO: Add a proper supervision tree
  // Children could be inspected then passed to the service in order
  // to know the "names" of the servers.
  //assert Ok(subject) =
  //  supervisor.start(fn(children) {
  //    children
  //    |> supervisor.add(supervisor.worker(session.start))
  //  })

  // Starts 1 instance of the session server
  let assert Ok(session) = session.start(Nil)

  let request_pipeline = fn(request: request.Request(mist.Connection)) -> response.Response(
    mist.ResponseData,
  ) {
    request
    |> middleware.process_form()
    |> middleware.from_mist_request()
    |> web.router(session)
    |> middleware.into_mist_response()
    |> middleware.to_bit_builder()
  }

  let assert Ok(Nil) =
    mist.new(request_pipeline)
    |> mist.port(8088)
    |> mist.start_http()

  process.sleep_forever()
}
