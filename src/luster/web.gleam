import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/string
import gleam/uri
import luster/events
import luster/store
import luster/web/pages/game
import luster/web/pages/home
import luster/web/pages/layout
import mist
import nakai
import nakai/html

// --- Middleware and Routing --- //

// TODO: La alternativa es un evento ShowAlert + redirect
pub type Context(record, html, message) {
  Context(
    store: store.Store(record),
    params: List(#(String, String)),
    selector: process.Selector(message),
  )
}

pub fn router(
  request: request.Request(mist.Connection),
  context: Context(game.Model, html, message),
) -> response.Response(mist.ResponseData) {
  case request.method, request.path_segments(request) {
    http.Get, [] -> {
      let records = store.all(context.store)

      home.Model(records)
      |> home.view()
      |> render(with: layout.view)
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
      |> render(with: layout.view)
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

    http.Get, ["events"] -> {
      events.start(request)
    }

    http.Get, ["assets", ..] -> {
      serve_assets(request)
    }

    _, _ -> {
      not_found()
    }
  }
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
