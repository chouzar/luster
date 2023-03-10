import gleam/string

/// Generates a triplet proquint
pub fn triplet() -> String {
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
