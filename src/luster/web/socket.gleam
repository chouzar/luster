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
import luster/games/three_line_poker as g
import luster/systems/pubsub.{type PubSub}
import luster/systems/session
import luster/web/tea_game as tea
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Binary, Closed, Custom, Shutdown, Text,
}
import nakai

pub type Message {
  UpdateGameState
  Close
}

pub type Action {
  Play(g.Message)
  Select(tea.Message)
}

pub opaque type State {
  State(
    session_id: Int,
    session: Subject(session.Message),
    pubsub: PubSub(Int, Message),
    model: tea.Model,
  )
}

pub fn start(
  request: Request(Connection),
  session_id: Int,
  session: Subject(session.Message),
  pubsub: PubSub(Int, Message),
) -> Response(ResponseData) {
  mist.websocket(
    request: request,
    on_init: build_init(_, session_id, session, pubsub),
    on_close: on_close,
    handler: handle_message,
  )
}

fn build_init(
  _conn: WebsocketConnection,
  session_id: Int,
  session: Subject(session.Message),
  pubsub: PubSub(Int, Message),
) -> #(State, Option(Selector(Message))) {
  let self = process.new_subject()
  pubsub.register(pubsub, session_id, self)
  let model = tea.init()

  #(
    State(session_id, session, pubsub, model),
    Some(
      process.new_selector()
      |> process.selecting(self, identity),
    ),
  )
}

fn on_close(state: State) -> Nil {
  let session_id = int.to_string(state.session_id)
  io.println("closing a connection for session: " <> session_id)
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
          let model = case action {
            Play(message) ->
              case session.next(state.session, message) {
                Ok(_gamestate) -> state.model
                Error(error) -> tea.update(state.model, tea.Alert(error))
              }

            Select(message) -> tea.update(state.model, message)
          }

          pubsub.broadcast(state.pubsub, state.session_id, UpdateGameState)

          let state = State(..state, model: model)
          Continue(state, None)
        }

        Error(Nil) -> {
          io.println("out of bound message:")
          io.debug(bits)
          Continue(state, None)
        }
      }
    }

    Custom(UpdateGameState) -> {
      let gamestate = session.gamestate(state.session)

      state.model
      |> tea.view(gamestate)
      |> nakai.to_inline_string()
      |> tap(mist.send_text_frame(conn, _))

      Continue(state, None)
    }

    Custom(Close) -> {
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
