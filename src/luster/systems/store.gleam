import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/order
import gleam/otp/actor

type State(x) {
  State(counter: Int, records: List(Record(x)))
}

type Record(x) {
  Record(id: Int, uuid: String, value: x)
}

pub opaque type Message(x) {
  Create(caller: process.Subject(String), value: x)
  Update(caller: process.Subject(Result(String, Nil)), uuid: String, value: x)
  Delete(uuid: String)
  All(caller: process.Subject(List(#(String, x))))
  One(caller: process.Subject(Result(x, Nil)), uuid: String)
  Stop
}

type Store(x) =
  process.Subject(Message(x))

pub fn start() -> Result(Store(x), actor.StartError) {
  actor.start(State(0, []), handle)
}

pub fn create(store: Store(x), value: x) -> String {
  actor.call(store, Create(_, value), 100)
}

pub fn update(store: Store(x), uuid: String, value: x) -> Result(String, Nil) {
  actor.call(store, Update(_, uuid, value), 100)
}

pub fn delete(store: Store(x), uuid: String) -> Nil {
  actor.send(store, Delete(uuid))
}

pub fn all(store: Store(x)) -> List(#(String, x)) {
  actor.call(store, All(_), 100)
}

pub fn one(store: Store(x), uuid: String) -> Result(x, Nil) {
  actor.call(store, One(_, uuid), 100)
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
      let uuid = uuid4()
      let Nil = process.send(caller, uuid)
      let record = Record(counter, uuid, value)
      let state = State(counter, [record, ..state.records])

      actor.continue(state)
    }

    Update(caller, id, value) -> {
      case list.pop(state.records, with_uuid(_, id)) {
        Ok(#(record, records)) -> {
          let record = Record(..record, value: value)
          let state = State(..state, records: [record, ..records])
          let Nil = process.send(caller, Ok(id))

          actor.continue(state)
        }

        Error(Nil) -> {
          let Nil = process.send(caller, Error(Nil))

          actor.continue(state)
        }
      }
    }

    Delete(id) -> {
      case list.pop(state.records, with_uuid(_, id)) {
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
      case list.find(state.records, with_uuid(_, id)) {
        Ok(record) -> {
          let Nil = process.send(caller, Ok(record.value))

          actor.continue(state)
        }

        Error(Nil) -> {
          let Nil = process.send(caller, Error(Nil))

          actor.continue(state)
        }
      }
    }

    Stop -> {
      actor.Stop(process.Normal)
    }
  }
}

fn with_uuid(record: Record(x), uuid: String) -> Bool {
  record.uuid == uuid
}

fn by_id(record_a: Record(x), record_b: Record(x)) -> order.Order {
  int.compare(record_a.id, record_b.id)
}

fn to_tuple(record: Record(x)) -> #(String, x) {
  #(record.uuid, record.value)
}

// Found at: https://stackoverflow.com/a/67863695
fn uuid4() {
  let assert <<u0:32, u1:16, _:4, u2:12, _:2, u3:30, u4:32>> =
    strong_rand_bytes(16)

  let assert <<tl:32, tm:16, thv:16, csr:8, csl:8, n:48>> = <<
    u0:size(32),
    u1:size(16),
    52:size(4),
    u2:size(12),
    2:size(2),
    u3:size(30),
    u4:size(32),
  >>

  let assert Ok(uuid) =
    format("~8.16.0b-~4.16.0b-~4.16.0b-~2.16.0b~2.16.0b-~12.16.0b", [
      tl,
      tm,
      thv,
      csr,
      csl,
      n,
    ])
    |> to_bit_array()
    |> bit_array.to_string()

  uuid
}

@external(erlang, "crypto", "strong_rand_bytes")
fn strong_rand_bytes(size: Int) -> BitArray

@external(erlang, "io_lib", "format")
fn format(pattern: String, bytes: List(Int)) -> List(String)

@external(erlang, "erlang", "list_to_binary")
fn to_bit_array(list: List(String)) -> BitArray
