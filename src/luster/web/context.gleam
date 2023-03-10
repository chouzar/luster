import gleam/erlang/process.{Subject}
import luster/session

pub type Context {
  Context(session_pid: Subject(session.Message))
}
