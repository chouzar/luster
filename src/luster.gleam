import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import luster/store
import luster/web
import luster/web/tea_game
import mist
import chip

// TODO: Create a web, games and luster/runtime contexts
// TODO: Add a proper supervision tree
//assert Ok(subject) =
//  supervisor.start(fn(children) {
//    children
//    |> supervisor.add(supervisor.worker(session.start))
//  })

pub fn main() -> Nil {
  let assert Ok(store) = store.start()
  let assert Ok(registry) = chip.start()

  let request_pipeline = fn(request: request.Request(mist.Connection)) -> response.Response(
    mist.ResponseData,
  ) {
    web.router(request, registry, store)
  }

  let assert Ok(_server) =
    mist.new(request_pipeline)
    |> mist.port(4444)
    |> mist.start_https(
      certfile: env("LUSTER_CERT"),
      keyfile: env("LUSTER_KEY"),
    )

  store.create(store, tea_game.init())
  process.sleep_forever()
}

fn env(key: String) -> String {
  case envoy.get(key) {
    Ok(value) -> value
    Error(Nil) -> panic as "unable to find ENV"
  }
}
