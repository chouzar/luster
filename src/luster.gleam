import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import luster/line_poker/session
import luster/line_poker/store
import luster/pubsub
import luster/web
import mist

// TODO: Add a proper supervision tree.

// TODO: Add a proper ELMish loop (luster/web/elmish.gleam) and command system.
//   * ELM loop callback.
//   * Command system for side-effects.
//   * Decoder/Encoder callbacks.
// This would let me simplify the socket models.

// TODO: Consider transition to Lustre framework.

// TODO: Add open/close click to end game screen.

pub fn main() -> Nil {
  // Start the persistence store but clean before starting.
  let Nil = store.start()
  let Nil = store.clean()

  // Start the live sessions registry.
  let assert Ok(store) = session.start()

  // Start the pubsub system.
  let assert Ok(pubsub) = pubsub.start()

  // Define middleware pipeline for server and start it.
  let request_pipeline = fn(request: request.Request(mist.Connection)) -> response.Response(
    mist.ResponseData,
  ) {
    web.router(request, store, pubsub)
  }

  let assert Ok(_server) =
    mist.new(request_pipeline)
    |> mist.port(4444)
    |> mist.start_https(
      certfile: env("LUSTER_CERT"),
      keyfile: env("LUSTER_KEY"),
    )

  process.sleep_forever()
}

fn env(key: String) -> String {
  case envoy.get(key) {
    Ok(value) -> value
    Error(Nil) -> panic as "unable to find ENV"
  }
}
