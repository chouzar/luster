import gleam/erlang/process
import luster/store
import chip

pub type Session(record, message) {
  Session(
    store: process.Subject(store.Message(record)),
    registry: process.Subject(chip.Action(Int, message)),
  )
}
