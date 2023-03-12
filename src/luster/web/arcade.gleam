import gleam/map.{Map}
import gleam/erlang/process.{Subject}
import luster/util
import luster/session.{Message}
import luster/battleline
import luster/web/template
import luster/web/context.{Context}
import luster/web/payload.{HTML, Redirect, Render, Request, Response}
import gleam/bbmustache.{CompileError}

pub fn index(_request: Request) -> Response {
  Render(
    mime: HTML,
    document: template.new("src/luster/web/arcade/component/index.html"),
  )
}

pub fn new_battleline(
  _request: Request,
  session_pid: Subject(Message),
  player_id: String,
) -> Response {
  let p1 = battleline.Player(player_id)
  let p2 = battleline.Computer
  let state = battleline.new_game(p1, p2)

  let id = util.proquint_triplet()
  assert Nil = session.set(session_pid, id, state)

  Redirect(location: "/battleline/" <> id)
}
