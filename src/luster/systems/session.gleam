import gleam/erlang/process.{type ExitReason, type Subject, Normal}
import gleam/option.{None}
import gleam/otp/actor.{
  type InitResult, type Next, type StartError, Continue, Ready, Spec, Stop,
}
import luster/games/three_line_poker as g

type State {
  State(gamestate: g.GameState)
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

pub fn stop(session: Subject(Message)) -> ExitReason {
  actor.call(session, Halt(_), 100)
}

pub opaque type Message {
  GameState(caller: Subject(g.GameState))
  Next(caller: Subject(Result(g.GameState, g.Errors)), g.Message)
  Halt(caller: Subject(ExitReason))
}

fn handle_init() -> InitResult(State, Message) {
  let gamestate = g.new()
  Ready(State(gamestate), process.new_selector())
}

fn handle_message(message: Message, state: State) -> Next(Message, State) {
  case message {
    GameState(caller) -> {
      process.send(caller, state.gamestate)
      Continue(state, None)
    }

    Next(caller, message) -> {
      case g.next(state.gamestate, message) {
        Ok(gamestate) -> {
          let _ = process.send(caller, Ok(gamestate))
          let state = State(gamestate)
          Continue(state, None)
        }

        Error(error) -> {
          let _ = process.send(caller, Error(error))
          Continue(state, None)
        }
      }
    }

    Halt(caller) -> {
      process.send(caller, Normal)
      Stop(Normal)
    }
  }
}
