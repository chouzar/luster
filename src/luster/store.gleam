import gleam/list
import gleam/int
import gleam/order
import gleam/erlang/process
import gleam/otp/actor

type State(x) {
  State(counter: Int, records: List(Record(x)))
}

type Record(x) {
  Record(id: Int, value: x)
}

pub type Errors {
  NotFound(id: Int)
}

pub opaque type Message(x) {
  Create(caller: process.Subject(Int), value: x)
  Update(caller: process.Subject(Result(Int, Errors)), id: Int, value: x)
  Delete(id: Int)
  All(caller: process.Subject(List(#(Int, x))))
  One(caller: process.Subject(Result(x, Errors)), id: Int)
  Stop
}

pub type Store(x) =
  process.Subject(Message(x))

pub fn start() -> Result(Store(x), actor.StartError) {
  actor.start(State(0, []), handle)
}

pub fn create(store: Store(x), value: x) -> Int {
  actor.call(store, Create(_, value), 100)
}

pub fn update(store: Store(x), id: Int, value: x) -> Result(Int, Errors) {
  actor.call(store, Update(_, id, value), 100)
}

pub fn delete(store: Store(x), id: Int) -> Nil {
  actor.send(store, Delete(id))
}

pub fn all(store: Store(x)) -> List(#(Int, x)) {
  actor.call(store, All(_), 100)
}

pub fn one(store: Store(x), id: Int) -> Result(x, Errors) {
  actor.call(store, One(_, id), 100)
}

pub fn stop(store: Store(x)) -> Nil {
  actor.send(store, Stop)
}

fn handle(
  message: Message(x),
  state: State(x),
) -> actor.Next(Message(x), State(x)) {
  case message {
    Create(caller, value) -> {
      let counter = state.counter + 1
      let Nil = process.send(caller, counter)
      let record = Record(counter, value)
      let state = State(counter, [record, ..state.records])

      actor.continue(state)
    }

    Update(caller, id, value) -> {
      case list.pop(state.records, with_id(_, id)) {
        Ok(#(record, records)) -> {
          let record = Record(..record, value: value)
          let state = State(..state, records: [record, ..records])
          let Nil = process.send(caller, Ok(id))

          actor.continue(state)
        }

        Error(Nil) -> {
          let Nil = process.send(caller, Error(NotFound(id)))

          actor.continue(state)
        }
      }
    }

    Delete(id) -> {
      case list.pop(state.records, with_id(_, id)) {
        Ok(#(_record, records)) -> {
          let state = State(..state, records: records)

          actor.continue(state)
        }

        Error(Nil) -> {
          actor.continue(state)
        }
      }
    }

    All(caller) -> {
      let records =
        state.records
        |> list.sort(by_id)
        |> list.map(to_tuple)

      let Nil = process.send(caller, records)

      actor.continue(state)
    }

    One(caller, id) -> {
      case list.find(state.records, with_id(_, id)) {
        Ok(record) -> {
          let Nil = process.send(caller, Ok(record.value))

          actor.continue(state)
        }

        Error(Nil) -> {
          let Nil = process.send(caller, Error(NotFound(id)))

          actor.continue(state)
        }
      }
    }

    Stop -> {
      actor.Stop(process.Normal)
    }
  }
}

fn with_id(record: Record(x), id: Int) -> Bool {
  record.id == id
}

fn by_id(record_a: Record(x), record_b: Record(x)) -> order.Order {
  int.compare(record_a.id, record_b.id)
}

fn to_tuple(record: Record(x)) -> #(Int, x) {
  #(record.id, record.value)
}
