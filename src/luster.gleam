import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import luster/systems/pubsub
import luster/systems/sessions
import luster/systems/store
import luster/web
import mist

// TODO: Add a proper supervision tree
//assert Ok(subject) =
//  supervisor.start(fn(children) {
//    children
//    |> supervisor.add(supervisor.worker(session.start))
//  })

// TODO: Rename chip to be:
// register -> For adding an already created subject
// spawn -> For adding the subject in callback 

// TODO: Eventually Chip needs to have a way of registering 
// custom types and addressing the register, de-register through callbacks.
// OR accept Selectors

// OR use ETS underneath

// TODO: Create a compartment in Chip for unique subjects

pub fn main() -> Nil {
  // Start the persistence store but clean before starting.
  let Nil = store.start()
  let Nil = store.clean()

  // Start the live sessions store.
  let assert Ok(store) = sessions.start()

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
// --- Helpers --- //

//const adjectives = [
//  "salty", "brief", "noble", "glorious", "respectful", "tainted", "measurable",
//  "constant", "fake", "lighting", "cool", "sparkling", "painful", "stealthy"
//  "mighty", "activated", "lit", "memorable"
//]
//
//const subjects = [
//  "poker", "party", "danceoff", "bakeoff", "marathon", "club", "game",
//  "match", "rounds", "trap card", "battleline", "duel", "dungeon"
//]
//
//fn generate_name() -> String {
//  let assert Ok(adjective) =
//    adjectives
//    |> list.shuffle()
//    |> list.first()
//
//  let assert Ok(subject) =
//    subjects
//    |> list.shuffle()
//    |> list.first()
//
//  adjective <> " " <> subject
//}
//
