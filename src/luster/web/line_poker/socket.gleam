import gleam/bit_array
import gleam/erlang/process.{type Selector, type Subject, Normal}
import gleam/function.{identity, tap}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Next, Continue, Stop}
import gleam/result.{try}
import luster/line_poker/game as g
import luster/line_poker/session
import luster/pubsub.{type PubSub}
import luster/web/line_poker/view as tea
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Binary, Closed, Custom, Shutdown, Text,
}
import nakai

pub type Message {
  Update(tea.Message)
  PrepareHalt
  Halt
}

pub type Action {
  Play(g.Message)
  Select(tea.Message)
}

pub opaque type State {
  State(
    self: Subject(Message),
    session_id: Int,
    session: Subject(session.Message),
    pubsub: PubSub(Int, Message),
    model: tea.Model,
  )
}

pub fn start(
  request: Request(Connection),
  session: Subject(session.Message),
  pubsub: PubSub(Int, Message),
) -> Response(ResponseData) {
  mist.websocket(
    request: request,
    on_init: build_init(_, session, pubsub),
    on_close: on_close,
    handler: handle_message,
  )
}

fn build_init(
  _conn: WebsocketConnection,
  session: Subject(session.Message),
  pubsub: PubSub(Int, Message),
) -> #(State, Option(Selector(Message))) {
  // Create an internal subject to send messages to itself
  let self = process.new_subject()

  // Retrieve data from the session
  let record = session.get_record(session)

  // Register the subject to broacast messages across sockets
  pubsub.register(pubsub, record.id, self)

  // Initialize a live TEA-like model for the socket
  let model = tea.init(record.gamestate)

  // Monitor the session process so we can track if it goes down
  let monitor =
    session
    |> process.subject_owner()
    |> process.monitor_process()

  // Initialize state and enable selectors for self ref and the monitor ref
  #(
    State(self, record.id, session, pubsub, model),
    Some(
      process.new_selector()
      |> process.selecting(self, identity)
      |> process.selecting_process_down(monitor, fn(_down) { PrepareHalt }),
    ),
  )
}

fn on_close(state: State) -> Nil {
  let session_id = int.to_string(state.session_id)
  io.println("closing socket connection for session: " <> session_id)
  Nil
}

fn handle_message(
  state: State,
  conn: WebsocketConnection,
  message: WebsocketMessage(Message),
) -> Next(a, State) {
  case message {
    Binary(bits) -> {
      case parse_message(bits) {
        Ok(action) -> {
          state.session
          |> build_message(action)
          |> broadcast_message(state, _)

          Continue(state, None)
        }

        Error(Nil) -> {
          io.print("out of bound message: ")
          io.debug(bits)
          Continue(state, None)
        }
      }
    }

    Custom(Update(message)) -> {
      let model = tea.update(state.model, message)

      model
      |> tea.view()
      |> nakai.to_inline_string()
      |> tap(mist.send_text_frame(conn, _))

      Continue(State(..state, model: model), None)
    }

    Custom(PrepareHalt) -> {
      // At this point, last update messages are still being broadcasted/enqueued in
      // the socket mailbox. This works as a kind of buffer to let them being  
      // processed before shutdown. 
      let id = int.to_string(state.session_id)
      io.println("preparing to halt socket for session " <> id)
      process.send_after(state.self, 5000, Halt)
      Continue(state, None)
    }

    Custom(Halt) -> {
      // And shutdown for real.
      Stop(Normal)
    }

    Text(message) -> {
      io.println("out of bound message: " <> message)
      Continue(state, None)
    }

    Closed | Shutdown -> {
      Stop(Normal)
    }
  }
}

fn build_message(
  session: Subject(session.Message),
  action: Action,
) -> tea.Message {
  case action {
    Play(message) -> {
      case session.next(session, message) {
        Ok(gamestate) -> tea.UpdateGame(gamestate)
        Error(error) -> tea.Alert(error)
      }
    }

    Select(message) -> {
      message
    }
  }
}

fn broadcast_message(state: State, message: tea.Message) -> Nil {
  case message {
    tea.UpdateGame(_) as message -> {
      // When gamestate is updated broadcast it to all sockets
      pubsub.broadcast(state.pubsub, state.session_id, Update(message))
    }

    message -> {
      // When UI is updated only this socket needs to know
      process.send(state.self, Update(message))
    }
  }
}

// --- Decoders for incoming messages --- //

fn parse_message(bits: BitArray) -> Result(Action, Nil) {
  case bits {
    <<"draw-card":utf8, rest:bytes>> -> {
      use #(player) <- try(decode_draw_card(rest))
      Ok(Play(g.DrawCard(player)))
    }

    <<"play-card":utf8, rest:bytes>> -> {
      use #(player, slot, card) <- try(decode_play_card(rest))
      Ok(Play(g.PlayCard(player, slot, card)))
    }

    <<"select-card":utf8, rest:bytes>> -> {
      use #(card) <- try(decode_select_card(rest))
      Ok(Select(tea.SelectCard(card)))
    }

    <<"popup-toggle":utf8, _rest:bytes>> -> {
      Ok(Select(tea.ToggleScoring))
    }

    _other -> {
      Error(Nil)
    }
  }
}

fn decode_draw_card(bits: BitArray) -> Result(#(g.Player), Nil) {
  case bits {
    <<player:bytes-size(2)>> -> {
      use player <- try(decode_player(player))
      Ok(#(player))
    }

    _other -> Error(Nil)
  }
}

fn decode_play_card(bits: BitArray) -> Result(#(g.Player, g.Slot, g.Card), Nil) {
  case bits {
    <<
      player:bytes-size(2),
      slot:bytes-size(1),
      suit:bytes-size(3),
      rank:bytes-size(2),
    >> -> {
      use player <- try(decode_player(player))
      use slot <- try(decode_slot(slot))
      use suit <- try(decode_suit(suit))
      use rank <- try(decode_rank(rank))
      Ok(#(player, slot, g.Card(rank, suit)))
    }

    _other -> Error(Nil)
  }
}

fn decode_select_card(bits: BitArray) -> Result(#(g.Card), Nil) {
  case bits {
    <<suit:bytes-size(3), rank:bytes-size(2)>> -> {
      use suit <- try(decode_suit(suit))
      use rank <- try(decode_rank(rank))
      Ok(#(g.Card(rank, suit)))
    }

    _other -> Error(Nil)
  }
}

fn decode_player(bits: BitArray) -> Result(g.Player, Nil) {
  case bits {
    <<"p1":utf8>> -> Ok(g.Player1)
    <<"p2":utf8>> -> Ok(g.Player2)
    _ -> Error(Nil)
  }
}

fn decode_slot(bits: BitArray) -> Result(g.Slot, Nil) {
  case bits {
    <<"1":utf8>> -> Ok(g.Slot1)
    <<"2":utf8>> -> Ok(g.Slot2)
    <<"3":utf8>> -> Ok(g.Slot3)
    <<"4":utf8>> -> Ok(g.Slot4)
    <<"5":utf8>> -> Ok(g.Slot5)
    <<"6":utf8>> -> Ok(g.Slot6)
    <<"7":utf8>> -> Ok(g.Slot7)
    <<"8":utf8>> -> Ok(g.Slot8)
    <<"9":utf8>> -> Ok(g.Slot9)
    _ -> Error(Nil)
  }
}

fn decode_suit(bits: BitArray) -> Result(g.Suit, Nil) {
  case bits {
    <<"♠":utf8>> -> Ok(g.Spade)
    <<"♥":utf8>> -> Ok(g.Heart)
    <<"♦":utf8>> -> Ok(g.Diamond)
    <<"♣":utf8>> -> Ok(g.Club)
    _ -> Error(Nil)
  }
}

fn decode_rank(bits: BitArray) -> Result(Int, Nil) {
  use string <- try(bit_array.to_string(bits))
  use int <- try(int.parse(string))
  Ok(int)
}
