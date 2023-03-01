import gleam/bit_string
import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/uri
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/payload
import gleam/http/mime
import luster/web/template

pub fn process_form(req: Request(BitString)) -> Request(Map(String, String)) {
  request.map(req, decode_uri_string)
}

fn decode_uri_string(value: BitString) -> Map(String, String) {
  // An alternative is to use the: 
  // * `uri_string:dissect_query` from erlang
  // * `Plug.Conn.Query.decode` from elixir's Plug
  assert Ok(value) = bit_string.to_string(value)
  assert Ok(params) = uri.parse_query(value)
  map.from_list(params)
}

pub fn from_mist_request(
  req: Request(Map(String, String)),
  context: context,
) -> payload.Request(context) {
  payload.Request(
    method: req.method,
    path: req.path,
    form_data: req.body,
    context: context,
  )
}

pub fn into_mist_response(resp: payload.Response) -> Response(String) {
  case resp {
    Render(mime, templ) ->
      response.new(200)
      |> response.prepend_header("content-type", payload.content_type(mime))
      |> response.set_body(
        templ
        |> template.render(),
      )

    Static(mime, path) ->
      response.new(200)
      |> response.set_body(
        template.new(path)
        |> template.render(),
      )

    Redirect(location: path) ->
      response.new(303)
      |> response.prepend_header("location", path)

    Flash(message, color) ->
      response.new(200)
      |> response.prepend_header("content-type", payload.content_type(HTML))
      |> response.set_body(
        template.new("src/luster/web/component")
        |> template.from("flash.html")
        |> template.render(),
      )
  }
}

pub fn to_bit_builder(resp: Response(String)) -> Response(BitBuilder) {
  response.map(resp, bit_builder.from_string)
}
