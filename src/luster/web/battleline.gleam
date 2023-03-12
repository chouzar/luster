import gleam/result
import gleam/list
import gleam/map.{Map}
import gleam/string
import gleam/http
import gleam/io
import gleam/erlang/process.{Subject}
import luster/session.{Message}
import luster/battleline.{GameState, Player}
import luster/web/payload.{
  Flash, HTML, Render, Request, Response, Stream, TurboStream,
}
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/component/stream
import luster/web/template
import luster/web/battleline/component/card_front
import luster/web/battleline/component/card_back
import luster/web/battleline/component/card_pile

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
  player_id: String,
) -> Response {
  let state = session.get(session_pid, session_id)

  // This could be computed by the template module
  // Would also be useful to have another keyword
  // template.embed
  // template.add
  assert Ok(odd_pile) = card_pile.render(state.deck, card_back.Diamonds)
  assert Ok(draw_pile) = card_pile.render(state.deck, card_back.Clouds)
  // TODO: Being able to compose the template, with the ideas behind turbo_stream
  // * Both could be structural composed at the end
  // * Or just do a single `component` that can be embedded.
  Render(
    mime: HTML,
    document: template.new("src/luster/web/battleline/template/layout.html")
    |> template.args(replace: "odd-pile", with: odd_pile)
    |> template.args(replace: "draw-pile", with: draw_pile)
    |> template.args(replace: "session-id", with: session_id)
    // TODO: This one going to be removed, no need for player_id
    |> template.args(replace: "player-id", with: player_id),
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

  assert Nil = session.set(session_pid, session_id, state)

  assert Ok(odd_pile) = card_pile.render(state.deck, card_back.Diamonds)
  assert Ok(draw_pile) = card_pile.render(state.deck, card_back.Clouds)
  assert Ok(card) = card_front.render(card)

  Stream(
    document: stream.new()
    |> stream.add(odd_pile, do: Update, at: "odd-pile")
    |> stream.add(draw_pile, do: Update, at: "draw-pile")
    |> stream.add(card, do: Append, at: "player-hand"),
  )
}

// TODO: Build a validator module for maps
// x-spec
// Can be changeset like and based on predicates >-> Accumulates result errors
// If everything passes
// A last parameter could be used to map into a constructor record >-> Accumulates
//   This last parameter could be validated at compile time by using the dynamic type
fn validate(
  form: Map(String, String),
  keys: List(String),
) -> Result(List(String), Nil) {
  keys
  |> list.map(fn(key) { map.get(form, key) })
  |> result.all()
}
