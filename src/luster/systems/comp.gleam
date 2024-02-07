import gleam/erlang/process
import gleam/float
import gleam/function.{identity}
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result.{try}
import luster/games/three_line_poker as tlp
import luster/systems/session
import luster/web/socket

pub type Message {
  AssessMove
  Stop
}

type State {
  State(
    self: process.Subject(Message),
    session_id: String,
    player: tlp.Player,
    session: process.Subject(session.Message),
    pubsub: socket.PubSub,
  )
}

pub fn start(
  player: tlp.Player,
  session: process.Subject(session.Message),
  pubsub: socket.PubSub,
) -> Result(process.Subject(Message), actor.StartError) {
  actor.start_spec(actor.Spec(
    init: fn() { handle_init(player, session, pubsub) },
    init_timeout: 10,
    loop: handle_message,
  ))
}

fn handle_init(
  player: tlp.Player,
  session: process.Subject(session.Message),
  pubsub: socket.PubSub,
) -> actor.InitResult(State, Message) {
  let self = process.new_subject()

  let session_id = session.id(session)

  process.send(self, AssessMove)

  actor.Ready(
    State(self, session_id, player, session, pubsub),
    process.new_selector()
    |> process.selecting(self, identity),
  )
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  case message {
    AssessMove -> {
      let _ = {
        use gamestate <- try(session.get(state.session))
        use message <- try(assess_move(state.player, gamestate))
        use gamestate <- try(make_move(gamestate, message))
        let Nil = session.set(state.session, gamestate)
        let Nil =
          socket.broadcast(
            state.pubsub,
            state.session_id,
            socket.UpdateGameState,
          )

        Ok(Nil)
      }

      let _timer = process.send_after(state.self, between(50, 50), AssessMove)

      actor.continue(state)
    }

    Stop -> {
      actor.Stop(process.Normal)
    }
  }
}

fn assess_move(
  player: tlp.Player,
  gamestate: tlp.GameState,
) -> Result(tlp.Message, Nil) {
  let hand = tlp.player_hand(gamestate, player)
  let slots = tlp.available_plays(gamestate, player)

  case list.length(hand), tlp.current_player(gamestate) {
    size, current if size == tlp.max_hand_size && current == player -> {
      Ok(play_card(player, slots, hand))
    }

    size, current if size == tlp.max_hand_size && current != player -> {
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

fn play_card(player, slots, hand) -> tlp.Message {
  let assert Ok(slot) =
    slots
    |> list.shuffle()
    |> list.first()
  let assert Ok(card) =
    hand
    |> list.shuffle()
    |> list.first()
  tlp.PlayCard(player, slot, card)
}

fn draw_card(player) -> tlp.Message {
  tlp.DrawCard(player)
}

fn make_move(gamestate, message) {
  case tlp.next(gamestate, message) {
    Ok(gamestate) -> Ok(gamestate)
    Error(_) -> Error(Nil)
  }
}

fn between(start: Int, end: Int) -> Int {
  let period = int.to_float(end - start)
  let random =
    period
    |> float.multiply(float.random())
    |> float.round()

  random + start
}
