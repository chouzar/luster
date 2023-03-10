import gleam/map.{Map}
import gleam/http

/// Abstraction to render responses in an easier way.
pub type Request(context) {
  Request(
    method: http.Method,
    path: String,
    path_segments: List(String),
    form_data: Map(String, String),
    context: context,
  )
}

pub type Response {
  // TODO: document could be of the `Template` type
  Render(mime: MIME, document: String)
  Static(mime: MIME, path: String, file: String)
  Redirect(location: String)
  Flash(message: String, color: String)
  NotFound(message: String)
}

// TODO:
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

pub fn content_type(mime: MIME) -> String {
  case mime {
    HTML -> "text/html; charset=utf-8"
    CSS -> "text/css"
    Favicon -> "image/x-icon"
    TurboStream -> "text/vnd.turbo-stream.html; charset=utf-8"
  }
}
