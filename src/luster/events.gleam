import chip
import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/option.{type Option, Some}
import gleam/otp/actor
import gleam/result.{try}
import luster/session
import luster/store
import luster/web/codec
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Binary, Closed, Custom, Shutdown, Text,
}
import luster/web/pages/game
import nakai

pub opaque type Message {
  Close
}

pub opaque type State(record, message) {
  State(
    socket: process.Subject(Message),
    store: process.Subject(store.Message(record)),
    registry: process.Subject(chip.Action(Int, message)),
  )
}

pub fn start(
  request: Request(Connection),
  session: session.Session(game.Model, message),
) -> Response(ResponseData) {
  mist.websocket(
    request: request,
    on_init: build_init(session),
    on_close: on_close,
    handler: handler,
  )
}

fn build_init(
  session: session.Session(record, message),
) -> fn(WebsocketConnection) ->
  #(State(record, message), Option(process.Selector(Message))) {
  fn(_conn) {
    let subject = process.new_subject()

    #(
      State(subject, session.store, session.registry),
      Some(
        process.new_selector()
        |> process.selecting(subject, function.identity),
      ),
    )
  }
}

fn on_close(_state: State(record, message)) -> Nil {
  io.println("closing connection")
  Nil
}

fn handler(
  state: State(game.Model, message),
  conn: WebsocketConnection,
  message: WebsocketMessage(Message),
) -> actor.Next(a, State(game.Model, message)) {
  case message {
    Binary(bits) -> {
      let _ = {
        use #(session, blob) <- try(split(bits, 36))
        use session <- try(bit_array.to_string(session))
        use message <- try(parse_message(blob))
        use model <- try(store.one(state.store, session))

        let html =
          model
          |> game.update(message)
          |> function.tap(store.update(state.store, session, _))
          |> game.view()
          |> nakai.to_inline_string()

        let _ = mist.send_text_frame(conn, html)
        Ok(Nil)
      }

      actor.continue(state)
    }

    Text(_message) -> {
      actor.continue(state)
    }

    Custom(Close) -> {
      actor.Stop(process.Normal)
    }

    Closed | Shutdown -> {
      actor.Stop(process.Normal)
    }
  }
}

fn parse_message(bits: BitArray) -> Result(game.Message, Nil) {
  case bits {
    <<"\n\n":utf8, "draw-card":utf8, "\n\n":utf8, json:bytes>> -> {
      use player <- try(decode(from: json, using: codec.decoder_player))
      Ok(game.DrawCard(player))
    }

    <<"\n\n":utf8, "select-card":utf8, "\n\n":utf8, json:bytes>> -> {
      use card <- try(decode(from: json, using: codec.decoder_card))
      Ok(game.SelectCard(card))
    }

    <<"\n\n":utf8, "play-card":utf8, "\n\n":utf8, json:bytes>> -> {
      use slot <- try(decode(from: json, using: codec.decoder_slot))
      Ok(game.PlayCard(slot))
    }

    <<"\n\n":utf8, "popup-toggle":utf8, "\n\n":utf8, _json:bytes>> -> {
      Ok(game.ToggleScoring)
    }

    _other -> {
      Error(Nil)
    }
  }
}

fn split(bits: BitArray, at index: Int) -> Result(#(BitArray, BitArray), Nil) {
  let size = bit_array.byte_size(bits)

  use slice_l <- try(bit_array.slice(bits, 0, index))
  use slice_r <- try(bit_array.slice(bits, index, size - index))

  Ok(#(slice_l, slice_r))
}

fn decode(from json, using decoder) {
  case json.decode_bits(json, decoder) {
    Ok(value) -> {
      Ok(value)
    }

    Error(_) -> {
      Error(Nil)
    }
  }
}
