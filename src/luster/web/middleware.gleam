import gleam/bit_array
import gleam/bytes_builder
import gleam/map.{type Map}
import gleam/uri
import gleam/result
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import luster/web/payload.{
  type In, type MIME, type Out, Document, In, NotFound, Redirect,
}
import luster/web/context
import luster/web/plant
import mist.{type Connection, type ResponseData, Bytes}

pub fn process_form(
  request: Request(Connection),
) -> Request(Map(String, String)) {
  let assert Ok(body) = mist.read_body(request, 5000)
  request.map(body, decode_uri_string)
}

fn decode_uri_string(value: BitArray) -> Map(String, String) {
  let assert Ok(value) = bit_array.to_string(value)
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

fn server_error(_error: String) -> response.Response(String) {
  response.new(500)
  |> response.set_body("Error rendering component")
}

pub fn to_bit_builder(
  resp: response.Response(String),
) -> response.Response(ResponseData) {
  resp
  |> response.map(bytes_builder.from_string)
  |> response.map(Bytes(_))
}
