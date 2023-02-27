import gleam/string
import gleam/list
import gleam/http/request.{Request}

pub type MIME {
  HTML
  CSS
  Favicon
  TurboStream
}

pub const html = "text/html; charset=utf-8"

pub const turbo_stream = "text/vnd.turbo-stream.html; charset=utf-8"

pub const favicon = "image/x-icon"

pub const css = "text/css"

//pub type MIME {
//  Auto
//  Custom(value: String)
//}

// TODO: Must test and move to the server layer
pub fn content_type(req: Request(x)) -> String {
  let segments = request.path_segments(req)

  assert Ok(file) = list.last(segments)

  assert Ok(file_extension) =
    file
    |> string.split(on: ".")
    |> list.last()

  case file_extension {
    "ico" -> favicon
    "css" -> css
  }
}
