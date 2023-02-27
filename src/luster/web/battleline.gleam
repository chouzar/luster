import gleam/string
import gleam/map
import gleam/http/request
import gleam/http/response
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template
import luster/battleline.{GameState, Persia}
import luster/web.{Request, Response}
import luster/web/context.{Context}
import luster/web/battleline/component/turbo_stream.{Append, Update}
import luster/web/battleline/component/card
import luster/web/battleline/store
import luster/web/session
import gleam/io

pub type Parameters {
  // Param decoding should happen in this module
  Index(state: GameState, session_id: String, player_id: String)
  DrawCard(state: GameState, session_id: String, player_id: String)
}

// should only return gamestate?
pub fn index(request: Request) -> Response {
  let FormRequest(form: form, context: context, ..) = request

  case map.get(form, "session_id") {
    Ok(session_id) -> {
      let state = session.get(context.session, session_id)
      let draw_pile = card.render_draw_pile(state)

      // TODO: Create a top layout component
      // TODO: Create a board component
      // TODO: Being able to compose the template, with the ideas behind turbo_stream
      // * This module could have a `layout` and `component` functions
      // * Both could be structural composed at the end
      // * Or just do a single `component` that can be embedded.
      // * To achieve this there could be diff types, one with inner content
      //Transformed to:
      //response.new(200)
      //|> response.prepend_header("content-type", mime.html)
      //|> response.set_body(body)
      Template(
        mime: HTML,
        template: template.new(["/src/luster/web/battleline/component"])
        |> template.from(["index.html"])
        |> template.args(replace: "session-id", with: session_id)
        |> template.args(replace: "draw-pile", with: draw_pile),
      )
    }

    Error(Nil) -> {
      io.debug(
        "Error: Unable to find session_id" <> "Method: " <> request.method <> "/n" <> "Path: " <> request.path <> "/n" <> "Data: " <> string.inspect(
          form,
        ) <> "/n",
      )
      Flash(message: "Action not available", color: Red)
    }
  }
}

pub fn draw_card(
  req: Request(FormFields),
  context: Context,
  id: String,
) -> Response(String) {
  assert Ok(_player) = map.get(req.body, "player")

  let state =
    context.session
    |> session.get(id)

  let #(card, state) = battleline.draw_card(state, for: Persia)

  context.session
  |> session.set(id, state)

  let card = card.render_front(card)
  let draw_pile = card.render_draw_pile(state.deck)

  let body =
    turbo_stream.new()
    |> turbo_stream.add(draw_pile, do: Update, at: "draw-pile")
    |> turbo_stream.add(card, do: Append, at: "player-hand")
    |> turbo_stream.render()

  response.new(200)
  |> response.prepend_header("content-type", mime.turbo_stream)
  |> response.set_body(body)
}

pub fn assets(path: List(String)) -> Response(String) {
  response.new(200)
  |> response.set_body(
    template.new(["src", "luster", "web", "battleline", "assets"])
    |> template.from(path)
    |> template.render(),
  )
}
