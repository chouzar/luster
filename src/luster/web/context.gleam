import gleam/erlang/process.{Subject}
import luster/web/session

pub type Context {
  Context(session: Subject(session.Message))
}
