import chip
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import luster/session
import luster/web
import mist

//import gleam/erlang/process

// TODO: Create a web, games and luster/runtime contexts
// TODO: Add supervision tree

// TODO: What to fit in the context?
// * Different types on the parameters received from the router.
//   * Param decoding could happen in this module.
//   * Param decoding could happen depending on the header.
//     * Form data should be decoded accordingly.
// * Game state already loaded from store.
// * Different actions decoded from the parameters received from the router.
//   * Show(state: GameState, player_id: String).
//     | DrawCard(GameState, player_id: String).
//pub type Context {
//  None
//}

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

  // Starts 1 instance of the registry
  let assert Ok(registry) = chip.start()

  let request_pipeline = fn(request: Request(mist.Connection)) -> Response(
    mist.ResponseData,
  ) {
    web.router(request, registry, session)
  }

  let assert Ok(Nil) =
    mist.new(request_pipeline)
    |> mist.port(4444)
    |> mist.start_http()

  process.sleep_forever()
}
