import gleam/string
import gleam/io

pub fn report(arguments: List(String)) -> Nil {
  arguments
  |> string.join("\n")
  |> string.append("\n\n")
  |> io.print()
}

/// Generates a triplet proquint
pub fn proquint_triplet() -> String {
  id()
  |> string.slice(at_index: 6, length: 17)
}

fn id() -> String {
  15
  |> random_bytes()
  |> encode()
  |> proquint()
}

@external(erlang, "Elixir.Proquint", "encode")
fn proquint(binary: String) -> String

@external(erlang, "crypto", "strong_rand_bytes")
fn random_bytes(seed: Int) -> String

@external(erlang, "base64", "encode")
fn encode(binary: String) -> String

@external(erlang, "Elixir.File", "cwd!")
pub fn root_path() -> String

@external(erlang, "Elixir.File", "read")
pub fn read_file(path: String) -> Result(String, error)
