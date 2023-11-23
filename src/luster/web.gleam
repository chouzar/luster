import gleam/erlang/process.{type Subject}
import gleam/http.{Get, Post}
import luster/util
import luster/web/arcade
import luster/web/battleline
import luster/session
import luster/web/plant
import luster/web/payload.{type In, type Out, CSS, Document, Favicon, NotFound}

pub fn router(payload: In, session_pid: Subject(session.Message)) -> Out {
  let player_id = "Raúl"

  case payload.method, payload.path {
    Get, [] ->
      payload
      |> arcade.index()

    Post, ["new-battleline"] ->
      payload
      |> arcade.new_battleline(session_pid, player_id)

    Get, ["battleline", session_id] ->
      payload
      |> battleline.mount(session_pid, session_id, player_id)

    Post, ["battleline", session_id, "draw-card"] ->
      payload
      |> battleline.draw_card(session_pid, session_id, player_id)

    Get, ["assets", ..] ->
      payload
      |> assets()

    _, _ -> {
      util.report([
        "Error: Unable to find path",
        "Method: " <> http.method_to_string(payload.method),
        "Path: " <> payload.static_path,
      ])

      NotFound(message: "Page not found")
    }
  }
}

fn assets(payload: In) -> Out {
  // TODO: Find a generic way to get shared content.
  case payload.static_path {
    "/assets/battleline/styles.css" ->
      Document(
        mime: CSS,
        template: plant.static("/src/luster/web/battleline/assets/styles.css"),
      )

    "/assets/battleline/favicon.ico" ->
      Document(
        mime: Favicon,
        template: plant.static("/src/luster/web/battleline/assets/favicon.ico"),
      )
  }
}
