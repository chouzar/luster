import gleam/erlang/process.{Subject}
import luster/session.{Message}
import luster/battleline.{GameState, Player}
import luster/web/payload.{
  Flash, HTML, Render, Request, Response, Stream, TurboStream,
}
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/lay.{Layout, Many, Raw, Template}
import luster/web/battleline/component/card_front
import luster/web/battleline/component/card_back.{Clouds, Diamonds}
import luster/web/battleline/component/draw_deck

//pub type Action {
//  // TODO: 
//  // Param decoding should happen in this module
//  // Maybe only return gamestate and let the engine render
//  //Show(
//  //  session_pid: Subject(session.Message),
//  //  session_id: String,
//  //  player_id: String,
//  //)
//  //DrawCard(state: GameState, session_id: String, player_id: String)
//}

// TODO:
// should only return gamestate?

// TODO:
// Steps of a controller
// Validate fields
// Get state
// Modify state
// Build templates
// Render

pub fn mount(
  _request: Request,
  session_pid: Subject(Message),
  session_id: String,
  _player_id: String,
) -> Response {
  let state = session.get(session_pid, session_id)

  // TODO: Maybe the `payload.Render` type is redundant
  Render(
    mime: HTML,
    document: Layout(
      path: "src/luster/web/battleline/component/layout.html",
      contents: [
        #("session-id", Raw(session_id)),
        #("odd-pile", draw_deck.new(card_back.Clouds, state.deck)),
        #("draw-pile", draw_deck.new(card_back.Diamonds, state.deck)),
      ],
    ),
  )
}

pub fn draw_card(
  _request: Request,
  session_pid: Subject(Message),
  session_id: String,
  player_id: String,
) -> Response {
  let state = session.get(session_pid, session_id)
  let #(card, state) = battleline.draw_card(state, for: Player(player_id))

  let assert Nil = session.set(session_pid, session_id, state)

  // TODO: Maybe the `payload.Stream` type is redundant
  Stream(document: Many([
    turbo_stream.new(at: "player-hand", do: Append, with: card_front.new(card)),
    turbo_stream.new(
      at: "odd-pile",
      do: Update,
      with: draw_deck.new(card_back.Clouds, state.deck),
    ),
    turbo_stream.new(
      at: "draw-pile",
      do: Update,
      with: draw_deck.new(card_back.Diamonds, state.deck),
    ),
  ]))
}
