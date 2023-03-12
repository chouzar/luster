import gleam/string
import gleam/io

pub fn report(arguments: List(String)) -> Nil {
  arguments
  |> string.join("\n")
  |> string.append("\n")
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

external fn proquint(binary) -> String =
  "Elixir.Proquint" "encode"

external fn random_bytes(seed) -> String =
  "crypto" "strong_rand_bytes"

external fn encode(binary) -> String =
  "base64" "encode"

pub external fn root_path() -> String =
  "Elixir.File" "cwd!"

pub external fn read_file(path: String) -> Result(String, error) =
  "Elixir.File" "read"
