import gleam/erlang/process.{type Subject, Normal}
import gleam/float
import gleam/function.{identity}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/otp/actor.{
  type InitResult, type Next, type StartError, Continue, Ready, Spec, Stop,
}
import gleam/result.{try}
import luster/line_poker/game as g
import luster/line_poker/session
import luster/pubsub.{type PubSub}
import luster/web/line_poker/socket
import luster/web/line_poker/view as tea

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
  session: Subject(session.Message),
  pubsub: PubSub(Int, socket.Message),
) -> Result(Subject(Message), StartError) {
  actor.start_spec(Spec(
    init: fn() { handle_init(player, session, pubsub) },
    init_timeout: 10,
    loop: handle_message,
  ))
}

fn handle_init(
  player: g.Player,
  session: Subject(session.Message),
  pubsub: PubSub(Int, socket.Message),
) -> InitResult(State, Message) {
  let self = process.new_subject()

  let record = session.get_record(session)

  process.send(self, AssessMove)

  let monitor =
    session
    |> process.subject_owner()
    |> process.monitor_process()

  Ready(
    State(self, record.id, player, session, pubsub),
    process.new_selector()
    |> process.selecting(self, identity)
    |> process.selecting_process_down(monitor, fn(_down) { Halt }),
  )
}

fn handle_message(message: Message, state: State) -> Next(Message, State) {
  case message {
    AssessMove -> {
      let _ = {
        use record <- try(session.fetch_record(state.session))
        use message <- try(assess_move(record.gamestate, state.player))
        broadcast_message(state, message)
        Ok(Nil)
      }

      let _timer = process.send_after(state.self, between(150, 150), AssessMove)

      Continue(state, None)
    }

    Halt -> {
      let id = int.to_string(state.session_id)
      let player = case state.player {
        g.Player1 -> "player 1"
        g.Player2 -> "player 2"
      }

      io.println("halting computer " <> player <> " for session " <> id)
      Stop(Normal)
    }
  }
}

fn broadcast_message(state: State, message: g.Message) -> Nil {
  case session.next(state.session, message) {
    Ok(gamestate) -> {
      let message = tea.UpdateGame(gamestate)
      pubsub.broadcast(state.pubsub, state.session_id, socket.Update(message))
    }

    Error(_) -> {
      Nil
    }
  }
}

fn assess_move(
  gamestate: g.GameState,
  player: g.Player,
) -> Result(g.Message, Nil) {
  let hand = g.player_hand(gamestate, player)
  let slots = g.available_plays(gamestate, player)
  let phase = g.current_phase(gamestate)

  case phase, list.length(hand), g.current_player(gamestate) {
    g.End, _size, _player -> {
      Error(Nil)
    }

    _phase, size, current if size == g.max_hand_size && current == player -> {
      Ok(play_card(player, slots, hand))
    }

    _phase, size, current if size == g.max_hand_size && current != player -> {
      Error(Nil)
    }

    _phase, _size, current if current != player -> {
      Ok(draw_card(player))
    }

    _phase, 0, _player -> {
      Ok(draw_card(player))
    }

    _phase, _size, player -> {
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
