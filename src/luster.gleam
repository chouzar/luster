import gleam/erlang/process
import luster/web
import luster/store
import mist
import wisp
import luster/web/pages/game

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
  let secret_key_base = wisp.random_string(64)

  let assert Ok(store) = store.start()

  let context = web.Context(store: store, assets_path: priv("/assets"))

  store.create(store, game.init())

  let assert Ok(Nil) =
    wisp.mist_handler(web.pipeline(_, context), secret_key_base)
    |> mist.new()
    |> mist.port(4444)
    |> mist.start_http()

  process.sleep_forever()
}

fn priv(path: String) -> String {
  let assert Ok(directory) = wisp.priv_directory("luster")
  directory <> path
}
