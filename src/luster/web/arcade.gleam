import gleam/erlang/process.{Subject}
import luster/util
import luster/session.{Message}
import luster/battleline
import luster/web/plant
import luster/web/payload.{Document, HTML, In, Out, Redirect}

pub fn index(_payload: In) -> Out {
  Document(
    mime: HTML,
    template: plant.static("src/luster/web/arcade/component/index.html"),
  )
}

pub fn new_battleline(
  _payload: In,
  session_pid: Subject(Message),
  player_id: String,
) -> Out {
  let p1 = battleline.Player(player_id)
  let p2 = battleline.Computer
  let state = battleline.new(p1, p2)

  let id = util.proquint_triplet()
  let assert Nil = session.set(session_pid, id, state)

  Redirect(location: "/battleline/" <> id)
}
