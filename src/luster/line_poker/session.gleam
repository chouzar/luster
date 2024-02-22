import chip
import gleam/erlang/process.{type Subject, Normal}
import gleam/function.{identity, tap}
import gleam/list
import gleam/option.{None}
import gleam/otp/actor.{
  type InitResult, type Next, type StartError, Continue, Ready, Spec, Stop,
}
import gleam/string
import luster/line_poker/game as g
import luster/line_poker/store
import luster/web/line_poker/view as tea
import nakai

// We treat this chip registry instance as registry so it has a mix of session subject 
// operations as well as a CRUD-like API for retrieving its content (Record).

pub type Registry =
  process.Subject(chip.Message(Int, Message))

pub type Record {
  Record(id: Int, name: String, gamestate: g.GameState)
}

pub fn start() -> Result(Registry, StartError) {
  chip.start()
}

pub fn new_session(registry: Registry) -> Result(Subject(Message), StartError) {
  let session_id = unique_integer([Monotonic, Positive])

  chip.register_as(registry, session_id, fn() {
    actor.start_spec(Spec(
      init: fn() { handle_init(session_id) },
      init_timeout: 10,
      loop: handle_message,
    ))
  })
}

pub fn all_sessions(registry: Registry) -> List(Subject(Message)) {
  chip.all(registry)
}

pub fn get_session(registry: Registry, id: Int) -> Result(Subject(Message), Nil) {
  case chip.lookup(registry, id) {
    [] -> Error(Nil)
    [subject] -> Ok(subject)
    _subjects -> panic as "multiple subjects with same id"
  }
}

pub fn get_record(subject: Subject(Message)) -> Record {
  process.call(subject, GetRecord(_), 100)
}

pub fn fetch_record(subject: Subject(Message)) -> Result(Record, Nil) {
  case process.try_call(subject, GetRecord(_), 100) {
    Ok(record) -> Ok(record)
    Error(_call_error) -> Error(Nil)
  }
}

pub fn set_gamestate(subject: Subject(Message), gamestate: g.GameState) -> Nil {
  process.call(subject, SetGameState(_, gamestate), 100)
}

pub fn next(
  session: Subject(Message),
  message: g.Message,
) -> Result(g.GameState, g.Errors) {
  actor.call(session, Next(_, message), 100)
}

// Session actor API and callbacks

type State {
  State(self: Subject(Message), record: Record)
}

pub opaque type Message {
  GetRecord(caller: Subject(Record))
  SetGameState(caller: Subject(Nil), gamestate: g.GameState)
  Next(caller: Subject(Result(g.GameState, g.Errors)), g.Message)
  Halt
}

fn handle_init(session_id: Int) -> InitResult(State, Message) {
  let self = process.new_subject()

  let state =
    State(
      self: self,
      record: Record(id: session_id, name: generate_name(), gamestate: g.new()),
    )

  let selector =
    process.new_selector()
    |> process.selecting(self, identity)

  Ready(state, selector)
}

fn handle_message(message: Message, state: State) -> Next(Message, State) {
  case message {
    GetRecord(caller) -> {
      process.send(caller, state.record)
      Continue(state, None)
    }

    SetGameState(caller, gamestate) -> {
      // If game ended, queue up a message to halt actor
      case g.current_phase(gamestate) {
        g.End -> process.send(state.self, Halt)
        _other -> Nil
      }

      // Set new gamestate
      let record = Record(..state.record, gamestate: gamestate)
      let state = State(..state, record: record)

      process.send(caller, Nil)

      Continue(state, None)
    }

    Next(caller, message) -> {
      let result =
        state.record.gamestate
        |> g.next(message)
        |> tap(process.send(caller, _))

      let gamestate = case result {
        Ok(gamestate) -> gamestate
        Error(_) -> state.record.gamestate
      }

      case g.current_phase(gamestate) {
        g.End -> process.send(state.self, Halt)
        _phase -> Nil
      }

      let record = Record(..state.record, gamestate: gamestate)
      let state = State(..state, record: record)

      Continue(state, None)
    }

    Halt -> {
      let record =
        store.Record(
          id: state.record.id,
          name: state.record.name,
          document: tea.init(state.record.gamestate)
          |> tea.view()
          |> nakai.to_inline_string(),
        )

      store.put(state.record.id, record)

      Stop(Normal)
    }
  }
}

type Param {
  Monotonic
  Positive
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer(params: List(Param)) -> Int

const adjectives = [
  "salty", "brief", "noble", "glorious", "respectful", "tainted", "measurable",
  "constant", "fake", "lighting", "cool", "sparkling", "painful", "stealthy",
  "mighty", "activated", "lit", "memorable", "pink", "usual",
]

const subjects = [
  "poker", "party", "danceoff", "bakeoff", "marathon", "club", "game", "match",
  "rounds", "battleline", "duel", "dungeon", "siege", "encounter", "trap",
  "gleam", "routine", "thunder", "odyssey", "actor", "BEAM", "mockery",
]

fn generate_name() -> String {
  let assert Ok(adjective) =
    adjectives
    |> list.shuffle()
    |> list.first()

  let assert Ok(subject) =
    subjects
    |> list.shuffle()
    |> list.first()

  string.capitalise(adjective) <> " " <> string.capitalise(subject)
}
