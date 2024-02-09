import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/otp/actor.{type StartError}
import luster/systems/session
import chip

pub type Store =
  process.Subject(chip.Message(Int, session.Message))

pub fn start() -> Result(Store, StartError) {
  chip.start()
}

pub fn create(
  store: Store,
) -> Result(#(Int, Subject(session.Message)), StartError) {
  let id = new_id()
  case chip.register_as(store, id, session.start) {
    Ok(subject) -> Ok(#(id, subject))
    Error(failed) -> Error(failed)
  }
}

pub fn all(store: Store) -> List(#(Int, Subject(session.Message))) {
  chip.named(store)
  |> list.sort(fn(left, right) { int.compare(left.0, right.0) })
}

pub fn one(store: Store, id: Int) -> Result(Subject(session.Message), Nil) {
  case chip.lookup(store, id) {
    [] -> Error(Nil)
    [subject] -> Ok(subject)
    _subjects -> panic as "multiple subjects with same id"
  }
}

fn new_id() -> Int {
  unique_integer([Monotonic, Positive])
}

type Param {
  Monotonic
  Positive
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer(params: List(Param)) -> Int
