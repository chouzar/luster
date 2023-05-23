//import gleam/otp/supervisor
import gleam/erlang/process
import luster/web
import luster/session
import mist
import gleam/map.{Map}
import gleam/dynamic.{DecodeError, Dynamic}
import gleam/string
import gleam/int

//import gleam/erlang/process

// Add supervision tree

pub fn main() -> Nil {
  // TODO: Add a proper supervision tree
  // Children could be inspected then passed to the service in order
  // to know the "names" of the servers.
  //assert Ok(subject) =
  //  supervisor.start(fn(children) {
  //    children
  //    |> supervisor.add(supervisor.worker(session.start))
  //  })

  // Starts 1 instance of the session server
  let assert Ok(session) = session.start(Nil)

  let assert Ok(Nil) =
    mist.run_service(8088, web.service(session), max_body_limit: 400_000)
  process.sleep_forever()
}

pub fn test(_key: String) -> Result(Int, List(DecodeError)) {
  store()
  |> dynamic.from()
  |> dynamic.field(named: "A", of: natural)
}

fn store() -> Map(String, Int) {
  map.from_list([#("A", 1), #("B", -2), #("C", 3)])
}

fn natural(value: Dynamic) -> Result(Int, List(DecodeError)) {
  case dynamic.classify(value), dynamic.unsafe_coerce(value) {
    "Int", coerced_value if coerced_value > 0 -> Ok(coerced_value)

    "Int", coerced_value ->
      Error([
        DecodeError(
          expected: "Natural Number",
          found: int.to_string(coerced_value),
          path: [],
        ),
      ])

    _other, coerced_value ->
      Error([
        DecodeError(
          expected: "Not an integer",
          found: string.inspect(coerced_value),
          path: [],
        ),
      ])
  }
}
