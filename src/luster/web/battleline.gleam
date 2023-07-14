import gleam/list
import gleam/erlang/process.{Subject}
import luster/session.{Message}
import luster/battleline.{Player}
import luster/battleline/board
import luster/web/payload.{Document, HTML, In, NotFound, Out, TurboStream}
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/plant
import luster/web/battleline/component/alert_message
import luster/web/battleline/component/card_front
import luster/web/battleline/component/card_back
import luster/web/battleline/component/draw_deck
import luster/web/battleline/component/hand

pub fn mount(
  _payload: In,
  session_pid: Subject(Message),
  session_id: String,
  player_id: String,
) -> Out {
  let state = session.get(session_pid, session_id)

  let hand = battleline.hand(state, of: Player(player_id))
  let size = battleline.deck_size(state)

  Document(
    mime: HTML,
    template: plant.lay(
      from: "src/luster/web/battleline/component/layout.html",
      with: [
        #("session-id", plant.raw(session_id)),
        #("odd-pile", draw_deck.new(card_back.Clouds, size)),
        #("draw-pile", draw_deck.new(card_back.Diamonds, size)),
        #("player-hand", hand.new(hand)),
      ],
    ),
  )
}

pub fn draw_card(
  _payload: In,
  session_pid: Subject(Message),
  session_id: String,
  player_id: String,
) -> Out {
  let state = session.get(session_pid, session_id)

  case battleline.initial_draw(state, of: Player(player_id)) {
    Ok(state) -> {
      let hand = battleline.hand(state, of: Player(player_id))
      let size = battleline.deck_size(state)

      let assert Nil = session.set(session_pid, session_id, state)

      Document(
        mime: TurboStream,
        template: plant.many([
          turbo_stream.new(at: "player-hand", do: Update, with: hand.new(hand)),
          turbo_stream.new(
            at: "odd-pile",
            do: Update,
            with: draw_deck.new(card_back.Clouds, size),
          ),
          turbo_stream.new(
            at: "draw-pile",
            do: Update,
            with: draw_deck.new(card_back.Diamonds, size),
          ),
        ]),
      )
    }

    Error(error) -> {
      Document(
        mime: TurboStream,
        template: plant.many([
          turbo_stream.new(at: "alert-message", do: Update, with: alert(error)),
        ]),
      )
    }
  }
}

fn alert(error: battleline.Errors) -> plant.Template {
  case error {
    battleline.NotCurrentPhase ->
      alert_message.new("Not current phase", alert_message.Error)
    battleline.NotCurrentPlayer ->
      alert_message.new("Not current player", alert_message.Error)
    battleline.Board(board.NoCardInHand) ->
      alert_message.new("Card not in hand", alert_message.Error)
    battleline.Board(board.EmptyDeck) ->
      alert_message.new("Deck already empty", alert_message.Info)
    battleline.Board(board.MaxHandReached) ->
      alert_message.new("Hand at max", alert_message.Info)
    battleline.Board(board.NotClaimableSlot) ->
      alert_message.new("Slot is not claimable", alert_message.Info)
    battleline.Board(board.NotPlayableSlot) ->
      alert_message.new("Slot is not playable", alert_message.Warning)
  }
}
