import gleam/map.{Map}
import gleam/http
import luster/web/context.{Context}
import luster/web/plant.{Template}

/// Abstraction to render responses in an easier way.
pub type In {
  In(
    method: http.Method,
    static_path: String,
    path: List(String),
    form_data: Map(String, String),
    context: Context,
  )
}

pub type Out {
  Document(mime: MIME, template: Template)
  Redirect(location: String)
  NotFound(message: String)
}

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
