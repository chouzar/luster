import gleam/bit_array
import gleam/erlang/process
import gleam/function.{tap}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, Some}
import gleam/otp/actor
import gleam/result.{try}
import luster/store
import luster/web/codec
import luster/web/tea_game
import chip
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Binary, Closed, Custom, Shutdown, Text,
}
import nakai

pub opaque type Message {
  UpdateView
  Close
}

pub opaque type State {
  State(
    session_id: String,
    self: process.Subject(Message),
    registry: process.Subject(chip.Message(String, Message)),
    store: process.Subject(store.Message(tea_game.Model)),
  )
}

pub fn start(
  request: Request(Connection),
  registry: process.Subject(chip.Message(String, Message)),
  store: process.Subject(store.Message(tea_game.Model)),
) -> Response(ResponseData) {
  mist.websocket(
    request: request,
    on_init: build_init(_, registry, store),
    on_close: on_close,
    handler: handler,
  )
}

fn build_init(
  _conn: WebsocketConnection,
  registry: process.Subject(chip.Message(String, Message)),
  store: process.Subject(store.Message(tea_game.Model)),
) -> #(State, Option(process.Selector(Message))) {
  let subject = process.new_subject()

  #(
    State("", subject, registry, store),
    Some(
      process.new_selector()
      |> process.selecting(subject, function.identity),
    ),
  )
}

fn on_close(state: State) -> Nil {
  io.println("closing a connection for session: " <> state.session_id)
  Nil
}

fn handler(
  state: State,
  conn: WebsocketConnection,
  message: WebsocketMessage(Message),
) -> actor.Next(a, State) {
  case message {
    Text("session:" <> session) -> {
      let _ = chip.register_as(state.registry, session, fn() { Ok(state.self) })
      let state = State(..state, session_id: session)
      actor.continue(state)
    }

    Binary(bits) -> {
      let _ = {
        use message <- try(parse_message(bits))
        use model <- try(store.one(state.store, state.session_id))

        model
        |> tea_game.update(message)
        |> tap(store.update(state.store, state.session_id, _))

        chip.lookup(state.registry, state.session_id)
        |> list.map(fn(socket) { process.send(socket, UpdateView) })

        Ok(Nil)
      }

      actor.continue(state)
    }

    Custom(UpdateView) -> {
      let _ = {
        use model <- try(store.one(state.store, state.session_id))

        model
        |> tea_game.view()
        |> nakai.to_inline_string()
        |> tap(mist.send_text_frame(conn, _))

        Ok(Nil)
      }

      actor.continue(state)
    }

    Text(message) -> {
      io.println("out of bound message: " <> message)
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

fn parse_message(bits: BitArray) -> Result(tea_game.Message, Nil) {
  case bits {
    <<"draw-card":utf8, "\n\n":utf8, json:bytes>> -> {
      use player <- try(decode(from: json, using: codec.decoder_player))
      Ok(tea_game.DrawCard(player))
    }

    <<"select-card":utf8, "\n\n":utf8, json:bytes>> -> {
      use card <- try(decode(from: json, using: codec.decoder_card))
      Ok(tea_game.SelectCard(card))
    }

    <<"play-card":utf8, "\n\n":utf8, json:bytes>> -> {
      use slot <- try(decode(from: json, using: codec.decoder_slot))
      Ok(tea_game.PlayCard(slot))
    }

    <<"popup-toggle":utf8, "\n\n":utf8, _json:bytes>> -> {
      Ok(tea_game.ToggleScoring)
    }

    bits -> {
      use message <- try(bit_array.to_string(bits))
      io.println("out of bound action: " <> message)
      Error(Nil)
    }
  }
}

fn decode(from json, using decoder) {
  case json.decode_bits(json, decoder) {
    Ok(value) -> Ok(value)

    Error(_) -> {
      use message <- try(to_string(json))
      io.println("malformed JSON data: " <> message)
      Error(Nil)
    }
  }
}

fn to_string(bits: BitArray) -> Result(String, Nil) {
  case bit_array.to_string(bits) {
    Ok(message) -> Ok(message)
    Error(Nil) -> {
      io.println("malformed Blob data:")
      io.debug(bits)
      Error(Nil)
    }
  }
}
