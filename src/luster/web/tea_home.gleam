import gleam/int
import gleam/list
import gleam/pair
import nakai/html
import nakai/html/attrs
import luster/games/three_line_poker as g

// --- Elmish Lobby --- //

pub type Model {
  Model(games: List(#(Int, g.GameState)))
}

pub fn view(model: Model) -> html.Node(a) {
  let ids = list.map(model.games, pair.first)

  html.Fragment([
    create_game_form(),
    html.ol([attrs.class("lobby-games")], list.map(ids, listed_lobby_game)),
  ])
}

fn create_game_form() -> html.Node(a) {
  // TODO: This form makes me thing that the full HTTP request needs to be encoded
  html.form([attrs.method("post"), attrs.action("/battleline")], [
    html.input([attrs.type_("submit"), attrs.value("Create new game")]),
  ])
}

fn listed_lobby_game(id: Int) -> html.Node(a) {
  let id = int.to_string(id)
  let anchor = html.a_text([attrs.href("/battleline/" <> id)], nth(id))
  html.li([], [anchor])
}

fn nth(id: String) -> String {
  case id {
    "1" -> "1st"
    "2" -> "2nd"
    n -> n <> "th"
  }
}
