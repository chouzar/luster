//import gleam/otp/supervisor
import gleam/erlang/process
import luster/web
import luster/session
import mist

//import gleam/erlang/process

// Add supervision tree

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

  let assert Ok(Nil) =
    mist.run_service(8088, web.service(session), max_body_limit: 400_000)
  process.sleep_forever()
}
