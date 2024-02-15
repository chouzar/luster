import gleam/int
import gleam/list
import luster/games/three_line_poker as g
import nakai/html
import nakai/html/attrs

// --- Elmish Lobby --- //

pub type Model {
  Model(games: List(#(Int, g.GameState)))
}

type GameMode {
  PlayerVsPlayer
  PlayerVsComp
  CompVsComp
}

pub fn view(model: Model) -> html.Node(a) {
  let cards = list.map(model.games, dashboard_card)
  html.section([attrs.class("lobby")], [
    html.div([attrs.class("row center control-panel")], [
      html.div([attrs.class("column evenly")], [
        create_game_form(PlayerVsPlayer, "2P Game"),
        create_game_form(PlayerVsComp, "1P Game"),
        create_game_form(CompVsComp, "Comp Game"),
      ]),
    ]),
    html.div([attrs.class("games column wrap")], cards),
  ])
}

fn create_game_form(mode: GameMode, text: String) -> html.Node(a) {
  html.form([attrs.method("post"), attrs.action("/battleline")], [
    html.input([
      attrs.type_("number"),
      attrs.name("quantity"),
      attrs.Attr(name: "min", value: "1"),
      attrs.Attr(name: "max", value: "100"),
      attrs.value("1"),
    ]),
    case mode {
      PlayerVsPlayer ->
        html.input([
          attrs.type_("hidden"),
          attrs.name("PlayerVsPlayer"),
          attrs.value(""),
        ])
      PlayerVsComp ->
        html.input([
          attrs.type_("hidden"),
          attrs.name("PlayerVsComp"),
          attrs.value(""),
        ])
      CompVsComp ->
        html.input([
          attrs.type_("hidden"),
          attrs.name("CompVsComp"),
          attrs.value(""),
        ])
    },
    html.input([attrs.type_("submit"), attrs.value(text)]),
  ])
}

fn dashboard_card(record: #(Int, g.GameState)) -> html.Node(a) {
  let #(id, _state) = record
  let id = int.to_string(id)
  html.div([attrs.id(id), attrs.class("dashboard-card")], [
    html.div([attrs.class("link")], [link(id)]),
    html.div([attrs.class("preview")], [frame(id)]),
  ])
}

fn frame(id: String) -> html.Node(a) {
  html.iframe(
    [
      attrs.width("100%"),
      attrs.height("100%"),
      attrs.Attr(name: "frameBorder", value: "0"),
      attrs.src("https://localhost:4444/battleline/" <> id),
    ],
    [],
  )
}

fn link(id: String) -> html.Node(a) {
  html.a_text(
    [attrs.href("https://localhost:4444/battleline/" <> id)],
    "Game " <> id,
  )
}
