import gleam/http
import wisp
import luster/store
import luster/web/pages/game
import luster/web/pages/home
import gleam/int
import nakai
import nakai/html
import nakai/html/attrs

// --- Middleware and Routing --- //

// TODO: Use SSE events as a way of executing UI commands as in Elm
// TODO: La alternativa es un evento ShowAlert + redirect
const game_path = "/battleline"

pub type Context(x) {
  Context(store: store.Store(x), assets_path: String)
}

pub fn pipeline(
  request: wisp.Request,
  context: Context(game.Model),
) -> wisp.Response {
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use <- wisp.serve_static(request, under: "/assets", from: context.assets_path)
  //database middleware to automatically store DB
  //use context <- web.set_store(registry)
  // Fetch from database

  use _request <- router(request, context)

  wisp.response(400)
}

pub fn router(
  request: wisp.Request,
  context: Context(game.Model),
  next: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case request.method, wisp.path_segments(request) {
    http.Get, [] -> {
      let records = store.all(context.store)

      home.Model(records)
      |> home.view()
      |> render(with: layout)
    }

    http.Post, ["battleline"] -> {
      let model = game.init()
      let _id = store.create(context.store, model)
      wisp.redirect("/")
    }

    http.Get, ["battleline", id] -> {
      let assert Ok(select_id) = int.parse(id)
      let assert Ok(model) = store.one(context.store, select_id)

      model
      |> game.view()
      |> render(with: layout)
    }

    http.Post, ["battleline", id] -> {
      use form <- wisp.require_form(request)
      let assert Ok(select_id) = int.parse(id)
      let assert Ok(model) = store.one(context.store, select_id)
      let assert Ok(message) = game.decode_message(form.values)

      let _ =
        model
        |> game.update(message)
        |> store.update(context.store, select_id, _)

      wisp.redirect(game_path <> "/" <> id)
    }

    _, _ -> {
      next(request)
    }
  }
}

fn render(
  body: html.Node(a),
  with layout: fn(html.Node(a)) -> html.Node(a),
) -> wisp.Response {
  let document =
    layout(body)
    |> nakai.to_string_builder()

  wisp.response(200)
  |> wisp.html_body(document)
}

fn layout(body: html.Node(a)) -> html.Node(a) {
  html.Html(
    [],
    [
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
        script("/assets/hotwired-turbo.js"),
      ]),
      html.Body([], [body]),
    ],
  )
}

fn script(source: String) {
  html.Element(
    tag: "script",
    attrs: [attrs.src(source), attrs.defer()],
    children: [],
  )
}
