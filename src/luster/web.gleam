import gleam/bytes_builder.{type BytesBuilder}
import gleam/erlang/process.{type Subject}
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import luster/battleline.{Player}
import luster/board.{type Card, Club, Diamond, Heart, Spade}
import luster/session.{type Message}
import mist
import nakai
import nakai/html.{type Node, Body, Element, Head, Html, Text}
import nakai/html/attrs

pub fn router(
  request: Request(mist.Connection),
  session,
) -> Response(mist.ResponseData) {
  let player_id = "Raúl"
  let path = request.path_segments(request)

  case request.method, path {
    Get, [] -> {
      let document = layout([index()])
      render(document)
    }

    Post, ["battleline"] -> {
      let id = new_battleline(session, player_id)
      redirect("/battleline/" <> id)
    }

    Get, ["battleline", session_id] -> {
      let state = session.get(session, session_id)

      let document = layout(board([], state, session_id, player_id))

      render(document)
    }

    Post, ["battleline", session_id, "draw-card"] -> {
      let state = session.get(session, session_id)

      case battleline.initial_draw(state, of: Player(player_id)) {
        Ok(state) -> {
          let assert Nil = session.set(session, session_id, state)

          let document = layout(board([], state, session_id, player_id))

          render(document)
        }

        Error(error) -> {
          let document =
            layout(board([board_error(error)], state, session_id, player_id))

          render(document)
        }
      }
    }

    Get, ["assets", ..] -> serve_assets(request)
    _, _ -> not_found()
  }
}

fn new_battleline(session_pid: Subject(Message), player_id: String) -> String {
  let p1 = battleline.Player(player_id)
  let p2 = battleline.Computer
  let state = battleline.new(p1, p2)

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

fn layout(body: List(Node(a))) -> Node(a) {
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
      Body([], body),
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

fn index() -> Node(a) {
  html.form(
    [attrs.method("post"), attrs.action("/battleline")],
    [html.input([attrs.type_("submit"), attrs.value("Play Line-Poker")])],
  )
}

fn board(
  alerts: List(Alert),
  state: battleline.GameState,
  session_id: String,
  player_id: String,
) -> List(Node(a)) {
  let hand = battleline.hand(state, of: Player(player_id))
  let size = battleline.deck_size(state)
  let alerts = list.map(alerts, alert)

  [
    html.form(
      [
        attrs.id("draw-card"),
        attrs.method("post"),
        attrs.action("/battleline/" <> session_id <> "/draw-card"),
      ],
      [
        html.input([
          attrs.type_("hidden"),
          attrs.name("player-id"),
          attrs.value(player_id),
        ]),
      ],
    ),
    html.section([attrs.id("alert-message"), attrs.class("alerts")], alerts),
    html.div(
      [attrs.class("board")],
      [
        html.div(
          [attrs.class("deck")],
          [
            html.section(
              [attrs.class("draw-pile")],
              [
                html.button(
                  [attrs.id("odd-pile"), attrs.formaction("draw-card")],
                  draw_deck(Clouds, size),
                ),
              ],
            ),
          ],
        ),
        html.div(
          [attrs.class("line")],
          [
            html.section(
              [attrs.class("hand")],
              [
                html.div([attrs.class("card back clouds")], []),
                html.div([attrs.class("card back clouds")], []),
                html.div([attrs.class("card back clouds")], []),
                html.div([attrs.class("card back clouds")], []),
                html.div([attrs.class("card back clouds")], []),
                html.div([attrs.class("card back clouds")], []),
                html.div([attrs.class("card back clouds")], []),
              ],
            ),
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
            html.section(
              [attrs.id("player-hand"), attrs.class("hand")],
              player_hand(hand),
            ),
          ],
        ),
        html.div(
          [attrs.class("deck")],
          [
            html.section(
              [attrs.class("draw-pile")],
              [
                html.button(
                  [attrs.id("draw-pile"), attrs.Attr("form", "draw-card")],
                  draw_deck(Diamonds, size),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ]
}

type Alert {
  Success(message: String)
  Info(message: String)
  Warning(message: String)
  Wrong(message: String)
}

fn alert(alert: Alert) -> Node(a) {
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

fn card_front(card: Card) -> Node(a) {
  let suit = case card.suit {
    Spade -> "♠"
    Heart -> "♥"
    Diamond -> "♦"
    Club -> "♣"
  }

  let color = case card.suit {
    Spade -> "blue"
    Heart -> "red"
    Diamond -> "green"
    Club -> "purple"
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

fn card_back(back: Background) -> Node(a) {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  html.div([attrs.class("card back " <> background)], [])
}

fn draw_deck(back: Background, size: Int) -> List(Node(a)) {
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

  let card = card_back(back)
  list.repeat(card, count)
}

fn player_hand(hand: List(Card)) -> List(Node(a)) {
  list.map(hand, card_front)
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
    |> io.debug()

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
