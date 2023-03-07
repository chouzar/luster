import gleam/bit_string
import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/uri
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/web/payload
import luster/web/template

pub fn process_form(req: Request(BitString)) -> Request(Map(String, String)) {
  request.map(req, decode_uri_string)
}

fn decode_uri_string(value: BitString) -> Map(String, String) {
  // TODO: An alternative is to use the: 
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
    path: request.path_segments(req),
    form_data: req.body,
    context: context,
  )
}

pub fn into_mist_response(resp: payload.Response) -> Response(String) {
  case resp {
    payload.Render(mime, templ) ->
      response.new(200)
      |> response.prepend_header("content-type", payload.content_type(mime))
      |> response.set_body(templ)

    //|> template.render(),
    payload.Static(mime, path) ->
      response.new(200)
      |> response.set_body(
        template.new(path)
        |> template.render(),
      )

    //|> template.render(),
    payload.Redirect(location: path) ->
      response.new(303)
      |> response.prepend_header("location", path)

    payload.Flash(message, color) ->
      response.new(200)
      |> response.prepend_header(
        "content-type",
        payload.content_type(payload.HTML),
      )
      |> response.set_body(
        template.new("src/luster/web/component")
        |> template.from("flash.html")
        |> template.render(),
      )

    //|> template.render(),
    // May not be relevant, as this will only ocurr at the route level
    payload.NotFound(message) ->
      response.new(404)
      |> response.set_body(message)
  }
}

pub fn to_bit_builder(resp: Response(String)) -> Response(BitBuilder) {
  response.map(resp, bit_builder.from_string)
}
