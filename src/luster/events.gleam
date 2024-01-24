import gleam/erlang/process
import gleam/otp/actor
import gleam/io
import gleam/bit_array
import gleam/option.{type Option, Some}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Binary, Closed, Custom, Shutdown, Text,
}

pub opaque type Message {
  Update
}

pub opaque type State {
  State(self: process.Subject(Message))
}

pub fn start(request: Request(Connection)) -> Response(ResponseData) {
  mist.websocket(
    request: request,
    on_init: on_init,
    on_close: on_close,
    handler: handler,
  )
}

fn on_init(
  _conn: WebsocketConnection,
) -> #(State, Option(process.Selector(Nil))) {
  let subject = process.new_subject()

  process.send(subject, Update)

  #(
    State(subject),
    Some(
      process.new_selector()
      |> process.selecting(subject, to_custom),
    ),
  )
}

fn to_custom(message: Message) -> Nil {
  case message {
    Update -> Nil
  }
}

fn on_close(state: State) -> Nil {
  io.println("closing connection:")
  io.debug(state)
  Nil
}

fn handler(
  state: State,
  conn: WebsocketConnection,
  message: WebsocketMessage(Nil),
) -> actor.Next(a, State) {
  case message {
    Text(<<"start: ":utf8, rest:bits>>) -> {
      let assert Ok(_) =
        mist.send_text_frame(conn, <<"started :":utf8, rest:bits>>)
      actor.continue(state)
    }

    Custom(Nil) -> {
      let assert Ok(_) = mist.send_text_frame(conn, <<"update":utf8>>)
      process.send_after(state.self, 1000, Update)
      actor.continue(state)
    }

    Text(bits) | Binary(bits) -> {
      case bit_array.to_string(bits) {
        Ok(message) -> io.println("out of bound event: " <> message)
        Error(_) -> io.println("out of bound event: malformed bits")
      }

      actor.continue(state)
    }

    Closed | Shutdown -> {
      actor.Stop(process.Normal)
    }
  }
}
