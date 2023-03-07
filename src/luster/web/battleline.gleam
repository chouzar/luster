import gleam/string
import gleam/map.{Map}
import gleam/http/request
import gleam/http/response
import luster/session
import luster/battleline.{GameState, Persia}
import luster/web/payload
import luster/web/template
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/battleline/context.{Context}
import luster/web/battleline/component/card_back
import luster/web/battleline/component/board
import luster/web/battleline/component/layout
import gleam/io

pub type Parameters {
  // Param decoding should happen in this module
  Index(state: GameState, session_id: String, player_id: String)
  DrawCard(state: GameState, session_id: String, player_id: String)
}

// should only return gamestate?
pub fn index(
  request: payload.Request(Context),
  session_id: session_id,
) -> payload.Response {
  let payload.Request(form_data: data, context: context, ..) = request

  case map.get(data, "session_id") {
    Ok(session_id) -> {
      let state = session.get(context.session, session_id)

      // TODO: Being able to compose the template, with the ideas behind turbo_stream
      // * Both could be structural composed at the end
      // * Or just do a single `component` that can be embedded.
      payload.Render(
        mime: payload.HTML,
        document: state
        |> board.render()
        |> layout.render(),
      )
    }

    Error(Nil) ->
      //io.debug(
      //  "Error: Unable to find session_id/n" <> "Method: " <> request.method <> "/n" <> "Path: " <> request.path <> "/n" <> "Data: " <> string.inspect(
      //    form,
      //  ) <> "/n",
      //)
      // TODO: Proper color here
      payload.Flash(message: "Action not available", color: "0F0F0F")
  }
}
//pub fn draw_card(
//  req: payload.Request(Context),
//  context: Context,
//  id: String,
//) -> Response(String) {
//  assert Ok(_player) = map.get(req.body, "player")
//
//  let state =
//    context.session
//    |> session.get(id)
//
//  let #(card, state) = battleline.draw_card(state, for: Persia)
//
//  context.session
//  |> session.set(id, state)
//
//  let card = card.render_front(card)
//  let draw_pile = card.render_draw_pile(state.deck)
//
//  let body =
//    turbo_stream.new()
//    |> turbo_stream.add(draw_pile, do: Update, at: "draw-pile")
//    |> turbo_stream.add(card, do: Append, at: "player-hand")
//    |> turbo_stream.render()
//
//  response.new(200)
//  |> response.prepend_header("content-type", mime.turbo_stream)
//  |> response.set_body(body)
//}
//
//pub fn assets(path: List(String)) -> Response(String) {
//  response.new(200)
//  |> response.set_body(
//    template.new(["src", "luster", "web", "battleline", "assets"])
//    |> template.from(path)
//    |> template.render(),
//  )
//}
