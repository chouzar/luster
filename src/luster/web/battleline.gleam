import gleam/erlang/process.{Subject}
import luster/session.{Message}
import luster/battleline.{Player}
import luster/web/payload.{Document, HTML, In, Out, TurboStream}
import luster/web/component/turbo_stream.{Append, Update}
import luster/web/plant
import luster/web/battleline/component/card_front
import luster/web/battleline/component/card_back
import luster/web/battleline/component/draw_deck

pub fn mount(
  _payload: In,
  session_pid: Subject(Message),
  session_id: String,
  _player_id: String,
) -> Out {
  let state = session.get(session_pid, session_id)

  Document(
    mime: HTML,
    template: plant.lay(
      from: "src/luster/web/battleline/component/layout.html",
      with: [
        #("session-id", plant.raw(session_id)),
        #("odd-pile", draw_deck.new(card_back.Clouds, state.deck)),
        #("draw-pile", draw_deck.new(card_back.Diamonds, state.deck)),
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
  let #(card, state) = battleline.draw_card(state, for: Player(player_id))

  let assert Nil = session.set(session_pid, session_id, state)

  Document(
    mime: TurboStream,
    template: plant.many([
      turbo_stream.new(
        at: "player-hand",
        do: Append,
        with: card_front.new(card),
      ),
      turbo_stream.new(
        at: "odd-pile",
        do: Update,
        with: draw_deck.new(card_back.Clouds, state.deck),
      ),
      turbo_stream.new(
        at: "draw-pile",
        do: Update,
        with: draw_deck.new(card_back.Diamonds, state.deck),
      ),
    ]),
  )
}
