import gleam/erlang/process.{Subject}
import luster/session

pub type Context {
  Context(session: Subject(session.Message))
}
