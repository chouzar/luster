import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import luster/systems/pubsub
import luster/systems/sessions
import luster/web
import mist
import gleam/iterator
import luster/systems/comp
import luster/games/three_line_poker as tlp

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
  let assert Ok(store) = sessions.start()
  let assert Ok(pubsub) = pubsub.start()

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

  create_games(store, pubsub)
  process.sleep_forever()
}

fn env(key: String) -> String {
  case envoy.get(key) {
    Ok(value) -> value
    Error(Nil) -> panic as "unable to find ENV"
  }
}

fn create_games(store, pubsub) {
  iterator.range(from: 1, to: 100)
  |> iterator.each(fn(_) {
    let assert Ok(#(id, subject)) = sessions.create(store)
    let assert Ok(_comp_1) = comp.start(tlp.Player1, id, subject, pubsub)
    let assert Ok(_comp_2) = comp.start(tlp.Player2, id, subject, pubsub)
  })
}
// --- Helpers --- //

//const adjectives = [
//  "salty", "brief", "noble", "glorious", "respectful", "tainted", "measurable",
//  "constant", "fake", "lighting", "cool", "sparkling", "painful", "superperfect",
//]
//
//const subjects = [
//  "poker", "party", "battle", "danceoff", "bakeoff", "marathon", "club", "game",
//  "match", "rounds",
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
