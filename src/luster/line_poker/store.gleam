pub type Record {
  Record(id: Int, name: String, document: String)
}

@external(erlang, "Elixir.Luster.Store", "start")
pub fn start() -> Nil

@external(erlang, "Elixir.Luster.Store", "all")
pub fn all() -> List(Record)

@external(erlang, "Elixir.Luster.Store", "put")
pub fn put(index: Int, record: Record) -> Nil

@external(erlang, "Elixir.Luster.Store", "get")
pub fn get(index: Int) -> Result(Record, Nil)

@external(erlang, "Elixir.Luster.Store", "dump")
pub fn clean() -> Nil
