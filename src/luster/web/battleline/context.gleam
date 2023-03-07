import gleam/erlang/process.{Subject}
import luster/battleline.{GameState}
import luster/session

pub type Context {
  Context(session: Subject(session.Message))
}
