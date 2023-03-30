import gleam/map.{Map}
import gleam/http
import luster/web/context.{Context}
import luster/web/lay.{Template}

/// Abstraction to render responses in an easier way.
pub type Request {
  Request(
    method: http.Method,
    static_path: String,
    path: List(String),
    form_data: Map(String, String),
    context: Context,
  )
}

pub type Response {

  // TODO: document could be of the `Template` type
  // TODO: Render and Stream should be the same but with more control on response header
  Render(mime: MIME, document: Template)
  Stream(document: Template)
  Static(mime: MIME, path: String)
  Redirect(location: String)
  Flash(message: String, color: String)
  NotFound(message: String)
}

// TODO:
// Mount(path: "html" or module)
// Layout(source: 
// Stream(patch: [
//  action: "replace", key: "id", value: "Hello",
//  action: "replace", key: "id", value: "Hello",
//  action: "replace", key: "id", value: "Hello",
// ])

pub type MIME {
  HTML
  CSS
  Favicon
  TurboStream
}
