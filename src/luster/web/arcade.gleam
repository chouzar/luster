import gleam/map.{Map}
import luster/session
import luster/id
import luster/battleline
import luster/web/template
import luster/web/context.{Context}
import luster/web/payload.{HTML, Redirect, Render, Request, Response}

pub fn index() -> Response {
  Render(
    mime: HTML,
    document: template.new("src/luster/web/arcade/component")
    |> template.from("index.html")
    |> template.render(),
  )
}

pub fn new_battleline(request: Request(Context)) -> Response {
  let p1 = battleline.Player(id.triplet())
  let p2 = battleline.Computer
  let state = battleline.new_game(p1, p2)

  let id = id.triplet()
  assert Nil = session.set(request.context.session, id, state)

  Redirect(location: "/battleline/" <> id)
}
