import gleam/pair
import gleam/list
import gleam/int
import nakai/html
import nakai/html/attrs

// --- Elmish Lobby --- //

pub type Model(r) {
  Model(games: List(#(String, r)))
}

pub fn view(model: Model(r)) -> html.Node(a) {
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

fn listed_lobby_game(id: String) -> html.Node(a) {
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
