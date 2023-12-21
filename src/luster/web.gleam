import gleam/bytes_builder.{type BytesBuilder}
import gleam/erlang/process.{type Subject}
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/string
import gleam/map.{type Map}
import gleam/uri
import gleam/bit_array
import luster/battleline
import luster/board
import luster/session.{type Message}
import mist
import nakai
import nakai/html.{type Node, Body, Element, Fragment, Head, Html, Text}
import nakai/html/attrs
import gleam/io

// TODO: Move registry and session to a context 
pub fn router(
  request: Request(mist.Connection),
  registry,
  session,
) -> Response(mist.ResponseData) {
  let path = request.path_segments(request)

  case request.method, path {
    Get, [] -> {
      let document = layout(page_index(session))
      render(document)
    }

    Post, ["battleline"] -> {
      let id = new_battleline(session)
      redirect("/battleline/" <> id)
    }

    Get, ["battleline", session_id] -> {
      let state = session.get(session, session_id)

      let document = layout(page_board([], state, session_id))

      render(document)
    }

    Post, ["battleline", session_id, "draw-card"] -> {
      // TODO: Move this to middleware 
      // TODO: Middleware to have actions
      let params = process_form(request)

      let assert Ok(player) = map.get(params, "playerId")

      let player = case player {
        "Player1" -> board.Player1
        "Player2" -> board.Player2
      }

      let state = session.get(session, session_id)

      case battleline.initial_draw(state, of: player) {
        Ok(state) -> {
          let assert Nil = session.set(session, session_id, state)

          let document = layout(page_board([], state, session_id))

          render(document)
        }

        Error(error) -> {
          let document =
            layout(page_board([board_error(error)], state, session_id))

          render(document)
        }
      }
    }

    Post, ["battleline", session_id, "claim-flag"] -> {
      todo
    }

    Post, ["battleline", session_id, "select-card"] -> {
      // TODO: Move this to middleware 
      // Detect form data header
      // Detect params in body
      // Detect fields to build selections
      let params = process_form(request)

      io.debug(params)
      todo
    }

    Post, ["battleline", session_id, "play-card"] -> {
      todo
    }

    Get, ["assets", ..] -> {
      serve_assets(request)
    }

    _, _ -> {
      not_found()
    }
  }
}

fn new_battleline(session_pid: Subject(Message)) -> String {
  let state = battleline.new()

  let id = proquint_triplet()
  let assert Nil = session.set(session_pid, id, state)
  id
}

fn board_error(error: battleline.Errors) -> Alert {
  case error {
    battleline.NotCurrentPhase -> Wrong("Not current phase")
    battleline.NotCurrentPlayer -> Wrong("Not current player")
    battleline.Board(board.NoCardInHand) -> Wrong("Card not in hand")
    battleline.Board(board.EmptyDeck) -> Info("Deck already empty")
    battleline.Board(board.MaxHandReached) -> Info("Hand at max")
    battleline.Board(board.NotClaimableSlot) -> Info("Slot is not claimable")
    battleline.Board(board.NotPlayableSlot) -> Warning("Slot is not playable")
  }
}

// HTML Pages and components

fn layout(body: Node(a)) -> Node(a) {
  Html(
    [],
    [
      Head([
        html.title("Line Poker"),
        html.meta([attrs.name("viewport"), attrs.content("width=device-width")]),
        html.link([
          attrs.rel("icon"),
          attrs.type_("image/x-icon"),
          attrs.href("/assets/favicon.ico"),
        ]),
        html.link([
          attrs.rel("stylesheet"),
          attrs.type_("text/css"),
          attrs.href("/assets/styles.css"),
        ]),
      ]),
      Body([], [body]),
    ],
  )
  //script("/assets/hotwired-turbo.js"),
}

fn script(source: String) {
  Element(
    tag: "script",
    attrs: [attrs.src(source), attrs.defer()],
    children: [],
  )
}

fn page_index(session) -> Node(a) {
  let ids = session.all(session)

  Fragment([
    html.form(
      [attrs.method("post"), attrs.action("/battleline")],
      [html.input([attrs.type_("submit"), attrs.value("Play Line-Poker")])],
    ),
    html.ol(
      [],
      list.map(
        ids,
        fn(id) {
          html.li([], [html.a_text([attrs.href("/battleline/" <> id)], id)])
        },
      ),
    ),
  ])
}

fn page_board(
  alerts: List(Alert),
  state: battleline.GameState,
  session_id: String,
) -> Node(a) {
  let p1_hand = battleline.hand(state, of: board.Player1)
  let p2_hand = battleline.hand(state, of: board.Player2)
  let alerts = list.map(alerts, component_alert)

  Fragment([
    html.section([attrs.id("alert-message"), attrs.class("alerts")], alerts),
    html.div(
      [attrs.class("board")],
      [
        draw_card_pile(state, session_id, board.Player2),
        html.div(
          [attrs.class("line")],
          [
            player_hand(state, session_id, board.Player2),
            html.section(
              [attrs.class("battleline")],
              [
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
                html.div([attrs.class("card back diamonds")], []),
              ],
            ),
            player_hand(state, session_id, board.Player1),
          ],
        ),
        draw_card_pile(state, session_id, board.Player1),
      ],
    ),
  ])
}

fn draw_card_pile(
  state: battleline.GameState,
  session_id: String,
  player: board.Player,
) -> Node(a) {
  let player = case player {
    board.Player1 -> "Player1"
    board.Player2 -> "Player2"
  }

  let size = battleline.deck_size(state)

  html.div(
    [attrs.class("deck")],
    [
      html.section(
        [attrs.class("draw-pile")],
        [
          button(
            "/battleline/" <> session_id <> "/draw-card",
            [#("playerId", player)],
            component_draw_deck(Diamonds, size),
          ),
        ],
      ),
    ],
  )
}

fn player_hand(
  state: battleline.GameState,
  session_id: String,
  player: board.Player,
) -> Node(a) {
  let hand = battleline.hand(state, of: player)

  let player_id = case player {
    board.Player1 -> "Player1"
    board.Player2 -> "Player2"
  }

  html.section(
    [attrs.class("hand")],
    list.map(
      hand,
      fn(card: board.Card) {
        let rank = int.to_string(card.rank)
        let suit = case card.suit {
          board.Spade -> "spade"
          board.Heart -> "heart"
          board.Diamond -> "diamond"
          board.Club -> "club"
        }

        button(
          "/battleline/" <> session_id <> "/select-card",
          [#("playerId", player_id), #("rank", rank), #("suit", suit)],
          component_card_front(card),
        )
      },
    ),
  )
}

fn button(
  action: String,
  params: List(#(String, String)),
  element: Node(a),
) -> Node(a) {
  html.form(
    [attrs.method("post"), attrs.action(action)],
    [
      Fragment(list.map(
        params,
        fn(param) {
          html.input([
            attrs.type_("hidden"),
            attrs.name(param.0),
            attrs.value(param.1),
          ])
        },
      )),
      html.button([], [element]),
    ],
  )
}

type Alert {
  Success(message: String)
  Info(message: String)
  Warning(message: String)
  Wrong(message: String)
}

fn component_alert(alert: Alert) -> Node(a) {
  let color = case alert {
    Success(_) -> "success"
    Info(_) -> "info"
    Warning(_) -> "warning"
    Wrong(_) -> "error"
  }

  html.div(
    [attrs.class("alert " <> color)],
    [html.span_text([], alert.message)],
  )
}

pub type Background {
  Clouds
  Diamonds
}

fn component_card_front(card: board.Card) -> Node(a) {
  let suit = case card.suit {
    board.Spade -> "♠"
    board.Heart -> "♥"
    board.Diamond -> "♦"
    board.Club -> "♣"
  }

  let color = case card.suit {
    board.Spade -> "blue"
    board.Heart -> "red"
    board.Diamond -> "green"
    board.Club -> "purple"
  }

  let rank = int.to_string(card.rank)

  html.div(
    [attrs.class("card front clouds " <> color)],
    [
      html.div(
        [attrs.class("upper-left")],
        [html.p([], [Text(rank)]), html.p([], [Text(suit)])],
      ),
      html.div([attrs.class("graphic")], [html.p([], [Text(suit)])]),
      html.div(
        [attrs.class("bottom-right")],
        [html.p([], [Text(rank)]), html.p([], [Text(suit)])],
      ),
    ],
  )
}

fn component_card_back(back: Background) -> Node(a) {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  html.div([attrs.class("card back " <> background)], [])
}

fn component_draw_deck(back: Background, size: Int) -> Node(a) {
  let count = case size {
    x if x > 48 -> 13
    x if x > 44 -> 12
    x if x > 40 -> 11
    x if x > 36 -> 10
    x if x > 32 -> 09
    x if x > 28 -> 08
    x if x > 24 -> 07
    x if x > 20 -> 06
    x if x > 16 -> 05
    x if x > 12 -> 04
    x if x > 08 -> 03
    x if x > 04 -> 02
    x if x > 00 -> 01
    0 -> 0
  }

  let card = component_card_back(back)
  html.div([], list.repeat(card, count))
}

// Server middleware helpers

fn render(html: Node(a)) -> Response(mist.ResponseData) {
  let body =
    html
    |> nakai.to_string_builder()
    |> bytes_builder.from_string_builder()
    |> mist.Bytes

  response.new(200)
  |> response.prepend_header("content-type", content_type(HTML))
  |> response.set_body(body)
}

fn redirect(path: String) -> Response(mist.ResponseData) {
  let body =
    bytes_builder.new()
    |> mist.Bytes

  response.new(303)
  |> response.prepend_header("location", path)
  |> response.set_body(body)
}

fn serve_assets(
  request: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  let path = string.join([root_path(), request.path], "")

  case read_file(path) {
    Ok(asset) -> {
      let mime = extract_mime(request.path)

      response.new(200)
      |> response.prepend_header("content-type", content_type(mime))
      |> response.set_body(mist.Bytes(asset))
    }

    _ -> not_found()
  }
}

fn not_found() -> Response(mist.ResponseData) {
  let body = bytes_builder.from_string("Not found")

  response.new(404)
  |> response.prepend_header("content-type", content_type(TextPlain))
  |> response.set_body(mist.Bytes(body))
}

fn process_form(request: Request(mist.Connection)) -> Map(String, String) {
  let assert Ok(request) = mist.read_body(request, 50)
  decode_uri_string(request.body)
}

fn decode_uri_string(value: BitArray) -> Map(String, String) {
  let assert Ok(value) = bit_array.to_string(value)
  let assert Ok(params) = uri.parse_query(value)
  map.from_list(params)
}

// https://www.iana.org/assignments/media-types/media-types.xhtml
type MIME {
  HTML
  CSS
  JavaScript
  Favicon
  TextPlain
}

fn content_type(mime: MIME) -> String {
  case mime {
    HTML -> "text/html; charset=utf-8"
    CSS -> "text/css"
    JavaScript -> "text/javascript"
    Favicon -> "image/x-icon"
    TextPlain -> "text/plain; charset=utf-8"
  }
}

fn extract_mime(path: String) -> MIME {
  let ext =
    path
    |> string.lowercase()
    |> extension()

  case ext {
    ".css" -> CSS
    ".ico" -> Favicon
    ".js" -> JavaScript
    _ -> panic as "unable to identify media type"
  }
}

pub fn proquint_triplet() -> String {
  random_bytes(15)
  |> base64_encode()
  |> proquint()
  |> string.slice(at_index: 6, length: 17)
}

@external(erlang, "Elixir.Proquint", "encode")
fn proquint(binary: String) -> String

@external(erlang, "crypto", "strong_rand_bytes")
fn random_bytes(seed: Int) -> String

@external(erlang, "base64", "encode")
fn base64_encode(binary: String) -> String

@external(erlang, "Elixir.File", "cwd!")
fn root_path() -> String

@external(erlang, "Elixir.File", "read")
fn read_file(path: String) -> Result(BytesBuilder, error)

@external(erlang, "Elixir.Path", "extname")
fn extension(path: String) -> String
