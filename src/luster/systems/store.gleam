@external(erlang, "Elixir.Luster.Store", "start")
pub fn start() -> Nil

@external(erlang, "Elixir.Luster.Store", "put")
pub fn create(id: Int, value: String) -> Nil

@external(erlang, "Elixir.Luster.Store", "all")
pub fn all() -> List(#(Int, String))

@external(erlang, "Elixir.Luster.Store", "get")
pub fn one(id: Int) -> Result(String, Nil)

@external(erlang, "Elixir.Luster.Store", "dump")
pub fn clean() -> Nil
