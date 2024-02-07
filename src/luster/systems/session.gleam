import chip
import gleam/erlang/process
import gleam/function.{identity}
import gleam/option.{None}
import gleam/otp/actor
import luster/games/three_line_poker as g
import luster/systems/store

pub opaque type Message {
  Id(caller: process.Subject(String))
  Set(g.GameState)
  Get(caller: process.Subject(Result(g.GameState, Nil)))
  Next(caller: process.Subject(Result(g.GameState, g.Errors)), g.Message)
  Stop
}

type State {
  State(id: String, store: process.Subject(store.Message(g.GameState)))
}

pub fn start(
  store: process.Subject(store.Message(g.GameState)),
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

pub fn next(
  session: process.Subject(Message),
  message: g.Message,
) -> Result(g.GameState, g.Errors) {
  actor.call(session, Next(_, message), 100)
}

pub fn set(session: process.Subject(Message), gamestate: g.GameState) -> Nil {
  actor.send(session, Set(gamestate))
}

pub fn get(session: process.Subject(Message)) -> Result(g.GameState, Nil) {
  actor.call(session, Get(_), 100)
}

fn handle_init(
  store: process.Subject(store.Message(g.GameState)),
  session_registry: process.Subject(chip.Message(String, Message)),
) -> actor.InitResult(State, Message) {
  let self = process.new_subject()
  let session_id = store.create(store, g.new())
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
      actor.continue(state)
    }

    Set(gamestate) -> {
      let _ = store.update(state.store, state.id, gamestate)
      actor.continue(state)
    }

    Get(caller) -> {
      state.store
      |> store.one(state.id)
      |> process.send(caller, _)

      actor.continue(state)
    }

    Next(caller, message) -> {
      let assert Ok(gamestate) = store.one(state.store, state.id)

      case g.next(gamestate, message) {
        Ok(gamestate) -> {
          let _ = store.update(state.store, state.id, gamestate)
          let _ = process.send(caller, Ok(gamestate))
          actor.continue(state)
        }

        Error(error) -> {
          let _ = process.send(caller, Error(error))
          actor.continue(state)
        }
      }
    }

    Stop -> {
      actor.Stop(process.Normal)
    }
  }
}
