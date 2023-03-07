import luster/session
import luster/battleline.{GameState, Persia}
import luster/web/payload.{HTML, Render, Request, Response, TurboStream}
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/context.{Context}
import luster/web/template
import luster/web/battleline/component/card_front
import luster/web/battleline/component/card_back
import luster/web/battleline/component/card_pile

pub type Parameters {
  // Param decoding should happen in this module
  Index(state: GameState, session_id: String, player_id: String)
  DrawCard(state: GameState, session_id: String, player_id: String)
}

// should only return gamestate?
pub fn index(request: Request(Context), session_id: String) -> Response {
  let state = session.get(request.context.session, session_id)

  let odd_pile = card_pile.render(state.deck, card_back.Diamonds)
  let draw_pile = card_pile.render(state.deck, card_back.Clouds)
  // TODO: Being able to compose the template, with the ideas behind turbo_stream
  // * Both could be structural composed at the end
  // * Or just do a single `component` that can be embedded.
  Render(
    mime: HTML,
    document: template.new("src/luster/web/battleline/template")
    |> template.from("layout.html")
    |> template.args(replace: "odd-pile", with: odd_pile)
    |> template.args(replace: "draw-pile", with: draw_pile)
    |> template.args(replace: "session-id", with: session_id)
    |> template.render(),
  )
}

pub fn draw_card(request: Request(Context), session_id: String) -> Response {
  let state = session.get(request.context.session, session_id)
  let #(card, state) = battleline.draw_card(state, for: Persia)

  assert Nil = session.set(request.context.session, session_id, state)

  let odd_pile = card_pile.render(state.deck, card_back.Diamonds)
  let draw_pile = card_pile.render(state.deck, card_back.Clouds)
  let card = card_front.render(card)

  Render(
    mime: TurboStream,
    document: turbo_stream.new()
    |> turbo_stream.add(odd_pile, do: Update, at: "odd-pile")
    |> turbo_stream.add(draw_pile, do: Update, at: "draw-pile")
    |> turbo_stream.add(card, do: Append, at: "player-hand")
    |> turbo_stream.render(),
  )
}
