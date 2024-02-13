import gleam/erlang/process.{type Subject, Normal}
import gleam/float
import gleam/function.{identity}
import gleam/int
import gleam/option.{None}
import gleam/list
import gleam/otp/actor.{
  type InitResult, type Next, type StartError, Continue, Ready, Spec, Stop,
}
import luster/games/three_line_poker as g
import luster/systems/session
import luster/systems/pubsub.{type PubSub}
import luster/web/socket

pub type Message {
  AssessMove
  Halt
}

type State {
  State(
    self: Subject(Message),
    session_id: Int,
    player: g.Player,
    session: Subject(session.Message),
    pubsub: PubSub(Int, socket.Message),
  )
}

pub fn start(
  player: g.Player,
  session_id: Int,
  session: Subject(session.Message),
  pubsub: PubSub(Int, socket.Message),
) -> Result(Subject(Message), StartError) {
  actor.start_spec(Spec(
    init: fn() { handle_init(player, session_id, session, pubsub) },
    init_timeout: 10,
    loop: handle_message,
  ))
}

fn handle_init(
  player: g.Player,
  session_id: Int,
  session: Subject(session.Message),
  pubsub: PubSub(Int, socket.Message),
) -> InitResult(State, Message) {
  let self = process.new_subject()

  process.send(self, AssessMove)

  Ready(
    State(self, session_id, player, session, pubsub),
    process.new_selector()
    |> process.selecting(self, identity),
  )
}

fn handle_message(message: Message, state: State) -> Next(Message, State) {
  case message {
    AssessMove -> {
      let gamestate = session.gamestate(state.session)

      case assess_move(state.player, gamestate) {
        Ok(message) ->
          case session.next(state.session, message) {
            Ok(_gamestate) ->
              pubsub.broadcast(
                state.pubsub,
                state.session_id,
                socket.UpdateGameState,
              )
            Error(_) -> Nil
          }

        Error(Nil) -> Nil
      }

      let _timer = process.send_after(state.self, between(25, 25), AssessMove)

      Continue(state, None)
    }

    Halt -> {
      Stop(Normal)
    }
  }
}

fn assess_move(
  player: g.Player,
  gamestate: g.GameState,
) -> Result(g.Message, Nil) {
  let hand = g.player_hand(gamestate, player)
  let slots = g.available_plays(gamestate, player)

  case list.length(hand), g.current_player(gamestate) {
    size, current if size == g.max_hand_size && current == player -> {
      Ok(play_card(player, slots, hand))
    }

    size, current if size == g.max_hand_size && current != player -> {
      Error(Nil)
    }

    _size, current if current != player -> {
      Ok(draw_card(player))
    }

    0, _player -> {
      Ok(draw_card(player))
    }

    _size, player -> {
      let assert Ok(move) =
        [play_card(player, slots, hand), draw_card(player)]
        |> list.shuffle()
        |> list.first()

      Ok(move)
    }
  }
}

fn play_card(player, slots, hand) -> g.Message {
  let assert Ok(slot) =
    slots
    |> list.shuffle()
    |> list.first()
  let assert Ok(card) =
    hand
    |> list.shuffle()
    |> list.first()
  g.PlayCard(player, slot, card)
}

fn draw_card(player) -> g.Message {
  g.DrawCard(player)
}

fn between(start: Int, end: Int) -> Int {
  let period = int.to_float(end - start)
  let random =
    period
    |> float.multiply(float.random())
    |> float.round()

  random + start
}
