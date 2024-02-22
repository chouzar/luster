import gleam/int
import gleam/list
import nakai/html
import nakai/html/attrs
import luster/line_poker/session
import luster/line_poker/store

// --- Elm-ish architecture with a Model and View callback --- //

pub type Model {
  Model(List(#(Int, String)))
}

type GameMode {
  PlayerVsPlayer
  PlayerVsComp
  CompVsComp
}

pub fn init(store: session.Registry) -> Model {
  let static_records =
    store.all()
    |> list.map(fn(record) { #(record.id, record.name) })

  let live_records =
    session.all_sessions(store)
    |> list.map(session.get_record)
    |> list.map(fn(record) { #(record.id, record.name) })

  let render_records =
    [static_records, live_records]
    |> list.concat()
    |> list.sort(fn(left, right) { int.compare(left.0, right.0) })

  Model(render_records)
}

pub fn view(model: Model) -> html.Node(a) {
  let Model(records) = model

  let cards = list.map(records, dashboard_card)
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

// --- Helpers to build the view  --- //

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

fn dashboard_card(record: #(Int, String)) -> html.Node(a) {
  let #(id, name) = record

  let id = int.to_string(id)
  html.div([attrs.id(id), attrs.class("dashboard-card")], [
    html.div([attrs.class("link")], [
      link("https://localhost:4444/battleline/" <> id, name),
    ]),
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

fn link(url: String, text: String) -> html.Node(a) {
  html.a_text([attrs.href(url)], text)
}
