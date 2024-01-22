import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import luster/store
import luster/web
import luster/web/pages/game
import mist

//import gleam/erlang/process
// TODO: Rename this project as card-field, line-poker, battle-group
// TODO: Change battleline for line-poker
// TODO: Create a web, games and luster/runtime contexts
// TODO: Add supervision tree
// TODO: Add a proper supervision tree
// Children could be inspected then passed to the service in order
// to know the "names" of the servers.
//assert Ok(subject) =
//  supervisor.start(fn(children) {
//    children
//    |> supervisor.add(supervisor.worker(session.start))
//  })

pub fn main() -> Nil {
  // Grab this secret from somewhere
  let assert Ok(store) = store.start()

  let request_pipeline = fn(request: request.Request(mist.Connection)) -> response.Response(
    mist.ResponseData,
  ) {
    let context = web.Context(store: store, params: [])

    web.router(request, context)
  }

  let assert Ok(Nil) =
    mist.new(request_pipeline)
    |> mist.port(4444)
    |> mist.start_http()

  store.create(store, game.init())
  process.sleep_forever()
}
