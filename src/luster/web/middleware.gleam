import gleam/bit_string
import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/uri
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/web/payload
import luster/web/context
import luster/web/lay.{Layout}

pub fn process_form(request: Request(BitString)) -> Request(Map(String, String)) {
  // TODO; If request is a form, add the form data
  request.map(request, decode_uri_string)
}

fn decode_uri_string(value: BitString) -> Map(String, String) {
  // An alternative is to use the: 
  // * `uri_string:dissect_query` from erlang
  // * `Plug.Conn.Query.decode` from elixir's Plug
  assert Ok(value) = bit_string.to_string(value)
  assert Ok(params) = uri.parse_query(value)
  map.from_list(params)
}

pub fn from_mist_request(req: Request(Map(String, String))) -> payload.Request {
  payload.Request(
    method: req.method,
    static_path: req.path,
    path: request.path_segments(req),
    form_data: req.body,
    context: context.None,
  )
}

// TODO: Move a lot of this logic to the payload type
// TODO: separate payload type into request/response
pub fn into_mist_response(resp: payload.Response) -> Response(String) {
  case resp {
    payload.Render(mime, templ) ->
      case lay.render(templ) {
        Ok(document) ->
          response.new(200)
          |> response.prepend_header("content-type", content_type(mime))
          |> response.set_body(document)

        Error(_) ->
          response.new(404)
          |> response.set_body("Error rendering component")
      }

    payload.Stream(templ) ->
      case lay.render(templ) {
        Ok(document) ->
          response.new(200)
          |> response.prepend_header(
            "content-type",
            content_type(payload.TurboStream),
          )
          |> response.set_body(document)

        Error(_) ->
          response.new(404)
          |> response.set_body("Error rendering component")
      }

    payload.Static(mime, path) ->
      case
        Layout(path: path, contents: [])
        |> lay.render()
      {
        Ok(document) ->
          response.new(200)
          |> response.prepend_header("content-type", content_type(mime))
          |> response.set_body(document)

        Error(_) ->
          response.new(404)
          |> response.set_body("Resource not found")
      }

    payload.Redirect(location: path) ->
      response.new(303)
      |> response.prepend_header("location", path)

    payload.Flash(message, color) ->
      case
        Layout(path: "src/luster/web/component/flash.html", contents: [])
        |> lay.render()
      {
        Ok(document) ->
          response.new(200)
          |> response.prepend_header("content-type", content_type(payload.HTML))
          |> response.set_body(document)

        Error(_) ->
          response.new(404)
          |> response.set_body("Flash not found")
      }

    payload.NotFound(message) ->
      response.new(404)
      |> response.set_body(message)
  }
}

pub fn to_bit_builder(resp: Response(String)) -> Response(BitBuilder) {
  response.map(resp, bit_builder.from_string)
}

fn content_type(mime: payload.MIME) -> String {
  case mime {
    payload.HTML -> "text/html; charset=utf-8"
    payload.CSS -> "text/css"
    payload.Favicon -> "image/x-icon"
    payload.TurboStream -> "text/vnd.turbo-stream.html; charset=utf-8"
  }
}
