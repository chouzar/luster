//import gleam/otp/supervisor
import gleam/erlang/process
import luster/battleline
import luster/session
import luster/web
import mist

//import gleam/erlang/process

// Add supervision tree

pub fn main() -> Nil {
  // TODO:
  // start with supervisor, 
  // children could be inspected 
  // then passed to the service
  //assert Ok(subject) =
  //  supervisor.start(fn(children) {
  //    children
  //    |> supervisor.add(supervisor.worker(session.start))
  //  })
  assert Ok(Nil) = mist.run_service(8088, web.service, max_body_limit: 400_000)
  process.sleep_forever()
}
