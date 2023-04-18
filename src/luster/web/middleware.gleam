import gleam/bit_string
import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/uri
import gleam/result
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/web/payload.{Document, In, MIME, NotFound, Out, Redirect}
import luster/web/context
import luster/web/plant

pub fn process_form(request: Request(BitString)) -> Request(Map(String, String)) {
  request.map(request, decode_uri_string)
}

fn decode_uri_string(value: BitString) -> Map(String, String) {
  let assert Ok(value) = bit_string.to_string(value)
  let assert Ok(params) = uri.parse_query(value)
  map.from_list(params)
}

pub fn from_mist_request(request: Request(Map(String, String))) -> In {
  In(
    method: request.method,
    static_path: request.path,
    path: request.path_segments(request),
    form_data: request.body,
    context: context.None,
  )
}

pub fn into_mist_response(payload: Out) -> Response(String) {
  case payload {
    Document(mime, template) ->
      template
      |> plant.render()
      |> result.map(render(mime, _))
      |> result.map_error(server_error)
      |> result.unwrap_both()

    Redirect(location: path) ->
      response.new(303)
      |> response.prepend_header("location", path)

    NotFound(message) ->
      response.new(404)
      |> response.set_body(message)
  }
}

fn render(mime_type: MIME, document: String) -> response.Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", payload.content_type(mime_type))
  |> response.set_body(document)
}

fn server_error(error: String) -> response.Response(String) {
  response.new(500)
  |> response.set_body("Error rendering component")
}

pub fn to_bit_builder(
  resp: response.Response(String),
) -> response.Response(BitBuilder) {
  response.map(resp, bit_builder.from_string)
}
