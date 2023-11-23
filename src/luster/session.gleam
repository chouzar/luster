import gleam/map.{type Map}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor.{type Next, type StartError, Stop}
import luster/battleline.{type GameState}

type State {
  State(sessions: Map(String, GameState))
}

pub type Message {
  SetSession(id: String, session: GameState)
  GetSession(caller: Subject(GameState), id: String)
  Close
}

pub fn start(_: Nil) -> Result(Subject(Message), StartError) {
  actor.start(State(map.new()), handle)
}

pub fn get(subject: Subject(Message), id: String) -> GameState {
  let make_message = fn(caller: Subject(GameState)) -> Message {
    GetSession(caller, id)
  }
  actor.call(subject, make_message, 100)
}

pub fn set(subject: Subject(Message), id: String, state: GameState) -> Nil {
  actor.send(subject, SetSession(id, state))
}

pub fn close(subject: Subject(Message)) -> Nil {
  actor.send(subject, Close)
}

fn handle(message: Message, state: State) -> Next(Message, State) {
  case message {
    SetSession(id, game_state) ->
      state.sessions
      |> map.insert(id, game_state)
      |> State()
      |> actor.continue()

    GetSession(caller, id) -> {
      let assert Ok(session) = map.get(state.sessions, id)
      let Nil = actor.send(caller, session)
      actor.continue(state)
    }

    Close -> Stop(process.Normal)
  }
}
