import chip
import gleam/erlang/process
import gleam/function.{identity}
import gleam/option.{None}
import gleam/otp/actor
import luster/games/three_line_poker as tlp
import luster/systems/store

pub opaque type Message {
  Id(caller: process.Subject(String))
  Set(tlp.GameState)
  Get(caller: process.Subject(Result(tlp.GameState, Nil)))
  Stop
}

type State {
  State(id: String, store: process.Subject(store.Message(tlp.GameState)))
}

pub fn start(
  store: process.Subject(store.Message(tlp.GameState)),
  session_registry: process.Subject(chip.Message(String, Message)),
) -> Result(process.Subject(Message), actor.StartError) {
  actor.start_spec(actor.Spec(
    init: fn() { handle_init(store, session_registry) },
    init_timeout: 10,
    loop: handle_message,
  ))
}

pub fn id(session: process.Subject(Message)) -> String {
  actor.call(session, Id(_), 100)
}

pub fn set(session: process.Subject(Message), gamestate: tlp.GameState) -> Nil {
  actor.send(session, Set(gamestate))
}

pub fn get(session: process.Subject(Message)) -> Result(tlp.GameState, Nil) {
  actor.call(session, Get(_), 100)
}

fn handle_init(
  store: process.Subject(store.Message(tlp.GameState)),
  session_registry: process.Subject(chip.Message(String, Message)),
) -> actor.InitResult(State, Message) {
  let self = process.new_subject()
  let session_id = store.create(store, tlp.new())
  let _ = chip.register_as(session_registry, session_id, fn() { Ok(self) })

  actor.Ready(
    State(id: session_id, store: store),
    process.new_selector()
    |> process.selecting(self, identity),
  )
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  case message {
    Id(caller) -> {
      process.send(caller, state.id)
      actor.Continue(state, None)
    }

    Set(gamestate) -> {
      let _ = store.update(state.store, state.id, gamestate)
      actor.Continue(state, None)
    }

    Get(caller) -> {
      state.store
      |> store.one(state.id)
      |> process.send(caller, _)

      actor.Continue(state, None)
    }

    Stop -> {
      actor.Stop(process.Normal)
    }
  }
}
