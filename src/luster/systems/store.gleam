@external(erlang, "Elixir.Luster.Store", "start")
pub fn start_static() -> Nil

@external(erlang, "Elixir.Luster.Store", "put")
pub fn create_static() -> Nil

@external(erlang, "Elixir.Luster.Store", "all")
pub fn all_static() -> List(#(Int, String))

@external(erlang, "Elixir.Luster.Store", "get")
pub fn one_static() -> Result(String, Nil)
