/// Abstraction to render responses in an easier way.
pub type Request(context) {
  Request(
    method: Method,
    path: String,
    form_data: Map(String, String),
    context: context,
  )
}

pub type Response {
  // template can have implicit status 200
  Render(mime: Mime, template: Template)
  Static(mime: Mime, path: String)
  Redirect(location: String)
  Flash(message: String, color: RGB)
  NotFound(message: String)
}

pub type MIME {
  HTML
  CSS
  Favicon
  TurboStream
}

fn content_type(mime: MIME) -> String {
  case mime {
    HTML -> "text/html; charset=utf-8"
    CSS -> "text/css"
    Favicon -> "image/x-icon"
    TurboStream -> "text/vnd.turbo-stream.html; charset=utf-8"
  }
}
