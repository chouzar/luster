import gleam/result
import gleam/list
import gleam/map.{Map}
import gleam/string
import gleam/http
import gleam/io
import luster/session
import luster/battleline.{GameState, Player}
import luster/web/payload.{Flash, HTML, Render, Request, Response, TurboStream}
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/context.{Context}
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
pub fn index(context: Context, session_id: String) -> Response {
  let state = session.get(context.session_pid, session_id)

  assert Player(player_id) = battleline.current_player(state)

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
    |> template.args(replace: "player-id", with: player_id)
    |> template.render(),
  )
}

pub fn draw_card(
  request: Request,
  context: Context,
  session_id: String,
) -> Response {
  let Request(form_data: form, ..) = request
  let Context(session_pid: session_pid) = context

  case validate(form, ["player-id"]) {
    Ok([player_id]) -> {
      let state = session.get(session_pid, session_id)
      let #(card, state) = battleline.draw_card(state, for: Player(player_id))

      assert Nil = session.set(context.session_pid, session_id, state)

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

    Error(_) -> {
      [
        "Error: Invalid action",
        "Method: " <> http.method_to_string(request.method),
        "Path: " <> request.path,
        "Data: Key" <> " key " <> "not found",
      ]
      |> string.join("/n")
      |> io.print()

      Flash("Invalid action", "#080808")
    }
  }
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
