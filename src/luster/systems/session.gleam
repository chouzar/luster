import gleam/erlang/process.{type Subject, Normal}
import gleam/function.{identity, tap}
import gleam/option.{None}
import gleam/otp/actor.{
  type InitResult, type Next, type StartError, Continue, Ready, Spec, Stop,
}
import luster/games/three_line_poker as g

type State {
  State(self: Subject(Message), gamestate: g.GameState)
}

pub fn start() -> Result(Subject(Message), StartError) {
  actor.start_spec(Spec(
    init: handle_init,
    init_timeout: 10,
    loop: handle_message,
  ))
}

pub fn next(
  session: Subject(Message),
  message: g.Message,
) -> Result(g.GameState, g.Errors) {
  actor.call(session, Next(_, message), 100)
}

pub fn gamestate(session: Subject(Message)) -> g.GameState {
  actor.call(session, GameState(_), 100)
}

pub opaque type Message {
  GameState(caller: Subject(g.GameState))
  Next(caller: Subject(Result(g.GameState, g.Errors)), g.Message)
  Halt
}

fn handle_init() -> InitResult(State, Message) {
  let gamestate = g.new()
  let self = process.new_subject()

  Ready(
    State(self, gamestate),
    process.new_selector()
    |> process.selecting(self, identity),
  )
}

fn handle_message(message: Message, state: State) -> Next(Message, State) {
  case message {
    GameState(caller) -> {
      process.send(caller, state.gamestate)
      Continue(state, None)
    }

    Next(caller, message) -> {
      let result =
        state.gamestate
        |> g.next(message)
        |> tap(process.send(caller, _))

      let gamestate = case result {
        Ok(gamestate) -> gamestate
        Error(_) -> state.gamestate
      }

      case g.current_phase(gamestate) {
        g.End -> process.send(state.self, Halt)
        _ -> Nil
      }

      Continue(State(..state, gamestate: gamestate), None)
    }

    Halt -> {
      Stop(Normal)
    }
  }
}
