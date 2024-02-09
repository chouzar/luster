import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/string
import gleam/uri
import luster/systems/comp
import luster/systems/session
import luster/systems/sessions
import luster/systems/pubsub
import luster/games/three_line_poker as tlp
import luster/web/socket
import luster/web/tea_game
import luster/web/tea_home
import mist
import nakai
import nakai/html
import nakai/html/attrs

pub fn router(
  request: request.Request(mist.Connection),
  store: sessions.Store,
  pubsub: pubsub.PubSub(Int, socket.Message),
) -> response.Response(mist.ResponseData) {
  case request.method, request.path_segments(request) {
    http.Get, [] -> {
      let records =
        sessions.all(store)
        |> list.map(fn(record) { #(record.0, session.gamestate(record.1)) })

      tea_home.Model(records)
      |> tea_home.view()
      |> render(with: fn(body) { layout("", body) })
    }

    http.Post, ["battleline"] -> {
      let assert Ok(#(id, subject)) = sessions.create(store)
      let assert Ok(_comp_1) = comp.start(tlp.Player1, id, subject, pubsub)
      let assert Ok(_comp_2) = comp.start(tlp.Player2, id, subject, pubsub)

      redirect("/")
    }

    http.Get, ["battleline", session_id] -> {
      let assert Ok(id) = int.parse(session_id)

      case sessions.one(store, id) {
        Ok(subject) ->
          tea_game.init()
          |> tea_game.view(session.gamestate(subject))
          |> render(with: fn(body) { layout(session_id, body) })

        Error(Nil) -> redirect("/")
      }
    }

    http.Get, ["events", session_id] -> {
      let assert Ok(id) = int.parse(session_id)

      case sessions.one(store, id) {
        Ok(subject) -> socket.start(request, id, subject, pubsub)
        Error(Nil) -> not_found()
      }
    }

    http.Get, ["assets", ..] -> {
      serve_assets(request)
    }

    _, _ -> {
      not_found()
    }
  }
}

fn layout(session: String, body: html.Node(a)) -> html.Node(a) {
  html.Html([], [
    html.Head([
      html.title("Line Poker"),
      html.meta([attrs.name("viewport"), attrs.content("width=device-width")]),
      html.meta([attrs.name("session"), attrs.content(session)]),
      html.link([
        attrs.rel("icon"),
        attrs.type_("image/x-icon"),
        attrs.defer(),
        attrs.href("/assets/favicon.ico"),
      ]),
      html.link([
        attrs.rel("stylesheet"),
        attrs.type_("text/css"),
        attrs.defer(),
        attrs.href("/assets/styles.css"),
      ]),
      html.Element(
        tag: "script",
        attrs: [attrs.src("/assets/script.js"), attrs.defer()],
        children: [],
      ),
    ]),
    html.Body([], [body]),
  ])
}

// https://www.iana.org/assignments/media-types/media-types.xhtml
type MIME {
  HTML
  CSS
  JavaScript
  Favicon
  TextPlain
}

fn render(
  body: html.Node(a),
  with layout: fn(html.Node(a)) -> html.Node(a),
) -> response.Response(mist.ResponseData) {
  let document =
    layout(body)
    |> nakai.to_string_builder()
    |> bytes_builder.from_string_builder()
    |> mist.Bytes

  response.new(200)
  |> response.prepend_header("content-type", content_type(HTML))
  |> response.set_body(document)
}

fn redirect(path: String) -> response.Response(mist.ResponseData) {
  response.new(303)
  |> response.prepend_header("location", path)
  |> response.set_body(mist.Bytes(bytes_builder.new()))
}

fn not_found() -> response.Response(mist.ResponseData) {
  response.new(404)
  |> response.prepend_header("content-type", content_type(TextPlain))
  |> response.set_body(mist.Bytes(bytes_builder.from_string("Not found")))
}

fn serve_assets(
  request: request.Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  let assert Ok(root) = erlang.priv_directory("luster")
  let assert asset = string.join([root, request.path], "")

  case read_file(asset) {
    Ok(asset) -> {
      let mime = extract_mime(request.path)

      response.new(200)
      |> response.prepend_header("content-type", content_type(mime))
      |> response.set_body(mist.Bytes(asset))
    }

    _ -> {
      not_found()
    }
  }
}

pub fn process_form(
  request: request.Request(mist.Connection),
) -> List(#(String, String)) {
  let assert Ok(request) = mist.read_body(request, 10_000)
  let assert Ok(value) = bit_array.to_string(request.body)
  let assert Ok(params) = uri.parse_query(value)
  params
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

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(bytes_builder.BytesBuilder, error)

@external(erlang, "filename", "extension")
fn extension(path: String) -> String
