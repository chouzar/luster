import gleam/bit_string
import gleam/bit_builder.{BitBuilder}
import gleam/map.{Map}
import gleam/uri
import gleam/http/request.{Request}
import gleam/http/response.{Response}

pub type FormFields =
  Map(String, String)

pub fn process_form(req: Request(BitString)) -> Request(FormFields) {
  request.map(req, decode_uri_string)
}

fn decode_uri_string(value: BitString) -> FormFields {
  //application/x-www-form-urlencoded
  // An alternative is to use the: 
  // * `uri_string:dissect_query` from erlang
  // * `Plug.Conn.Query.decode` from elixir's Plug
  assert Ok(value) = bit_string.to_string(value)
  assert Ok(params) = uri.parse_query(value)
  map.from_list(params)
}

pub fn to_bit_builder(resp: Response(String)) -> Response(BitBuilder) {
  response.map(resp, bit_builder.from_string)
}
