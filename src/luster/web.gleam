import gleam/http
import mist
import luster/store
import luster/web/pages/game
import luster/web/pages/home
import gleam/http/request
import gleam/http/response
import gleam/erlang
import gleam/string
import gleam/int
import gleam/bit_array
import gleam/bytes_builder
import nakai
import nakai/html
import nakai/html/attrs
import gleam/uri
import gleam/io

// --- Middleware and Routing --- //

// TODO: Use SSE events as a way of executing UI commands as in Elm
// TODO: La alternativa es un evento ShowAlert + redirect
pub type Context(record, html) {
  Context(store: store.Store(record), params: List(#(String, String)))
}

pub fn router(
  request: request.Request(mist.Connection),
  context: Context(game.Model, a),
) -> response.Response(mist.ResponseData) {
  case request.method, request.path_segments(request) {
    http.Get, [] -> {
      let records = store.all(context.store)

      home.Model(records)
      |> home.view()
      |> render(with: layout)
    }

    http.Post, ["battleline"] -> {
      let model = game.init()
      let _id = store.create(context.store, model)
      redirect("/")
    }

    http.Get, ["battleline", id] -> {
      let assert Ok(select_id) = int.parse(id)
      let assert Ok(model) = store.one(context.store, select_id)

      model
      |> game.view()
      |> render(with: layout)
    }

    http.Post, ["battleline", id] -> {
      let params = process_form(request)
      let assert Ok(select_id) = int.parse(id)
      let assert Ok(model) = store.one(context.store, select_id)
      let assert Ok(message) = game.decode_message(params)

      let _ =
        model
        |> game.update(message)
        |> store.update(context.store, select_id, _)

      redirect("/battleline/" <> id)
    }

    http.Get, ["assets", ..] -> {
      serve_assets(request)
    }

    _, _ -> {
      not_found()
    }
  }
}

fn layout(body: html.Node(a)) -> html.Node(a) {
  html.Html([], [
    html.Head([
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
      html.link([
        attrs.rel("stylesheet"),
        attrs.type_("text/css"),
        attrs.href("/assets/ztyles.css"),
      ]),
    ]),
    //script("/assets/hotwired-turbo.js"),
    html.Body([], [body]),
  ])
}

fn script(source: String) {
  html.Element(
    tag: "script",
    attrs: [attrs.src(source), attrs.defer()],
    children: [],
  )
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
  io.debug(request.path)
  let assert Ok(root) = erlang.priv_directory("luster")
  let assert asset = string.join([root, request.path], "")

  case read_file(asset) {
    Ok(asset) -> {
      let mime =
        extract_mime(request.path)
        |> io.debug()

      content_type(mime)
      |> io.debug()

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
    |> io.debug()
    |> string.lowercase()
    |> io.debug()
    |> extension()
    |> io.debug()

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
