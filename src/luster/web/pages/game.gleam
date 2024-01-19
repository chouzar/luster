import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/pair
import gleam/list
import gleam/map.{type Map}
import gleam/result.{try}
import luster/game/cardfield as cf
import gleam/int
import nakai/html
import nakai/html/attrs

// --- Elmish Game --- //

pub type Model {
  Model(
    name: String,
    alert: Option(Alert),
    selected_card: Map(cf.Player, Option(cf.Card)),
    gamestate: cf.GameState,
  )
}

type Event {
  Event(id: String, data: List(#(String, String)))
}

pub type Message {
  SelectCard(player: cf.Player, card: cf.Card)
  Move(action: cf.Action)
}

pub type Alert {
  Info(message: String)
  Warn(message: String)
  Bad(message: String)
}

pub fn init() -> Model {
  Model(
    name: generate_name(),
    alert: None,
    selected_card: map.new()
    |> map.insert(cf.Player1, None)
    |> map.insert(cf.Player2, None),
    gamestate: cf.new(),
  )
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    SelectCard(player, card) -> {
      case cf.current_phase(model.gamestate) {
        cf.PlayCardPhase1 | cf.PlayCardPhase2 | cf.PlayCardPhase3 ->
          case cf.current_player(model.gamestate) {
            current_player if player == current_player -> {
              let alert = Some(Info("Play card on a column"))
              let selected_card =
                map.insert(model.selected_card, player, Some(card))
              Model(..model, alert: alert, selected_card: selected_card)
            }

            _other -> {
              let alert = to_alert(cf.NotCurrentPlayer)
              Model(..model, alert: Some(alert))
            }
          }

        _other -> {
          let alert = to_alert(cf.NotCurrentPhase)
          Model(..model, alert: Some(alert))
        }
      }
    }

    Move(action) -> {
      case cf.next(model.gamestate, action) {
        Ok(state) -> {
          Model(..model, gamestate: state)
        }

        Error(error) -> {
          Model(..model, alert: Some(to_alert(error)))
        }
      }
    }
  }
}

pub fn view(model: Model) -> html.Node(a) {
  html.Fragment([
    view_game_info(model.gamestate),
    view_alert(model.alert),
    html.div(
      [attrs.class("board")],
      [
        view_card_pile(model.gamestate, cf.Player2),
        html.div(
          [attrs.class("field")],
          [
            view_hand(model.gamestate, cf.Player2),
            view_score_columns(model.gamestate, cf.Player2),
            view_slots(model, cf.Player2),
            view_score_totals(model.gamestate),
            view_slots(model, cf.Player1),
            view_score_columns(model.gamestate, cf.Player1),
            view_hand(model.gamestate, cf.Player1),
          ],
        ),
        view_card_pile(model.gamestate, cf.Player1),
      ],
    ),
  ])
}

// --- View board segments --- //

fn view_game_info(state: cf.GameState) -> html.Node(a) {
  let size =
    cf.deck_size(state)
    |> int.to_string()

  let phase = case cf.current_phase(state) {
    cf.FillHandPhase -> "Initial Draw"
    cf.PlayCardPhase1 -> "Play Card"
    cf.PlayCardPhase2 -> "Play Card"
    cf.PlayCardPhase3 -> "Play Card"
    cf.ReplentishPhase1 -> "Replentish Hand"
    cf.ReplentishPhase2 -> "Replentish Hand"
    cf.ReplentishPhase3 -> "Replentish Hand"
    cf.EndPhase -> "Game!"
  }

  let player = case cf.current_player(state) {
    cf.Player1 -> "Player 1"
    cf.Player2 -> "Player 2"
  }

  html.section(
    [attrs.id("alert-message"), attrs.class("alerts")],
    [
      html.div(
        [],
        [
          html.span_text([], "Deck size: " <> size),
          html.span_text([], "Phase: " <> phase),
          html.span_text([], "Current player: " <> player),
        ],
      ),
    ],
  )
}

fn view_alert(message: Option(Alert)) -> html.Node(a) {
  case message {
    Some(a) -> {
      html.section(
        [attrs.id("alert-message"), attrs.class("alerts")],
        [alert(a)],
      )
    }

    None -> {
      html.Fragment([])
    }
  }
}

fn view_card_pile(state: cf.GameState, player: cf.Player) -> html.Node(a) {
  let size = cf.deck_size(state)
  let event = encode_draw_card(player)

  html.div(
    [attrs.class("deck")],
    [html.section([attrs.class("draw-pile")], [form(event, draw_deck(size))])],
  )
}

fn view_score_totals(state: cf.GameState) -> html.Node(a) {
  let totals = cf.score_totals(state)

  html.section(
    [attrs.class("scores")],
    {
      use score <- list.map(totals)
      case score {
        #(Some(player), total) -> {
          let player = encode_player(player)
          let score = int.to_string(total)

          html.div(
            [attrs.class("score" <> " " <> player)],
            [html.span_text([], score)],
          )
        }

        #(None, total) -> {
          let score = int.to_string(total)

          html.div([attrs.class("score")], [html.span_text([], score)])
        }
      }
    },
  )
}

fn view_score_columns(state: cf.GameState, player: cf.Player) -> html.Node(a) {
  let columns = cf.score_columns(state)

  let scores = case player {
    cf.Player1 -> list.map(columns, pair.first)
    cf.Player2 -> list.map(columns, pair.second)
  }

  let player = encode_player(player)

  html.section(
    [attrs.class("scores")],
    {
      use score <- list.map(scores)
      let card = int.to_string(score.card_score)
      let formation = int.to_string(score.formation_bonus)

      html.div(
        [attrs.class("score" <> " " <> player)],
        [
          html.span_text([attrs.class("unit")], card),
          html.span_text([], " + "),
          html.span_text([attrs.class("formation")], formation),
        ],
      )
    },
  )
}

fn view_hand(state: cf.GameState, player: cf.Player) -> html.Node(a) {
  let hand = cf.player_hand(state, of: player)

  html.section(
    [attrs.class("hand")],
    list.map(
      hand,
      fn(card) {
        let event = encode_select_card(player, card)
        form(event, card_front(card))
      },
    ),
  )
}

fn view_slots(model: Model, player: cf.Player) -> html.Node(a) {
  let columns = cf.columns(model.gamestate, player)
  let assert Ok(selected_card) = map.get(model.selected_card, player)
  let player_class = encode_player(player)

  html.section(
    [attrs.class("slots")],
    {
      use slot_column <- list.map(columns)
      let #(slot, column) = slot_column

      case selected_card {
        Some(card) -> {
          let event = encode_play_card(player, slot, card)
          form(
            event,
            html.div(
              [attrs.class("slot" <> " " <> player_class)],
              list.map(column, card_front),
            ),
          )
        }

        None -> {
          html.div(
            [attrs.class("slot" <> " " <> player_class)],
            list.map(column, card_front),
          )
        }
      }
    },
  )
}

// --- View board components --- //

fn card_front(card: cf.Card) -> html.Node(a) {
  let suit = case card.suit {
    cf.Spade -> "♠"
    cf.Heart -> "♥"
    cf.Diamond -> "♦"
    cf.Club -> "♣"
  }

  let color = case card.suit {
    cf.Spade -> "blue"
    cf.Heart -> "red"
    cf.Diamond -> "green"
    cf.Club -> "purple"
  }

  let rank = int.to_string(card.rank)

  html.div(
    [attrs.class("card front clouds " <> color)],
    [
      html.div(
        [attrs.class("upper-left")],
        [html.p([], [html.Text(rank)]), html.p([], [html.Text(suit)])],
      ),
      html.div([attrs.class("graphic")], [html.p([], [html.Text(suit)])]),
      html.div(
        [attrs.class("bottom-right")],
        [html.p([], [html.Text(rank)]), html.p([], [html.Text(suit)])],
      ),
    ],
  )
}

fn card_back() -> html.Node(a) {
  html.div([attrs.class("card back sparkle")], [])
}

fn draw_deck(size: Int) -> html.Node(a) {
  let count = case size {
    x if x > 48 -> 13
    x if x > 44 -> 12
    x if x > 40 -> 11
    x if x > 36 -> 10
    x if x > 32 -> 09
    x if x > 28 -> 08
    x if x > 24 -> 07
    x if x > 20 -> 06
    x if x > 16 -> 05
    x if x > 12 -> 04
    x if x > 08 -> 03
    x if x > 04 -> 02
    x if x > 00 -> 01
    0 -> 0
  }

  let card = card_back()
  html.div([], list.repeat(card, count))
}

fn alert(alert: Alert) -> html.Node(a) {
  let color = case alert {
    Info(_) -> "info"
    Warn(_) -> "warning"
    Bad(_) -> "error"
  }

  html.div(
    [attrs.class("alert " <> color)],
    [html.span_text([], alert.message)],
  )
}

fn to_alert(error: cf.Errors) -> Alert {
  case error {
    cf.NotCurrentPhase -> Warn("Not current phase")
    cf.NotCurrentPlayer -> Warn("Not current player")
    cf.NoCardInHand -> Warn("Card not in hand")
    cf.EmptyDeck -> Info("Deck already empty")
    cf.MaxHandReached -> Info("Hand at max")
    cf.NotClaimableSlot -> Info("Slot is not claimable")
    cf.NotPlayableSlot -> Info("Slot is not playable")
  }
}

// --- View HTML Helpers --- //

fn form(event: Event, markup: html.Node(a)) -> html.Node(a) {
  let input = list.map(event.data, hidden_input)
  let button = button(event.id, markup)

  html.form(
    [attrs.id(event.id), attrs.method("post")],
    list.append(input, [button]),
  )
}

fn hidden_input(param: #(String, String)) -> html.Node(a) {
  html.input([attrs.type_("hidden"), attrs.name(param.0), attrs.value(param.1)])
}

fn button(form_id: String, markup: html.Node(a)) -> html.Node(a) {
  let form_attr = attrs.Attr(name: "form", value: form_id)
  html.button([form_attr], [markup])
}

// --- Helpers --- //

const adjectives = [
  "salty", "brief", "noble", "glorious", "respectful", "tainted", "measurable",
  "constant", "fake", "lighting", "cool", "sparkling", "painful", "superperfect",
]

const subjects = [
  "poker", "party", "battle", "danceoff", "bakeoff", "marathon", "club", "game",
  "match", "rounds",
]

fn generate_name() -> String {
  let assert Ok(adjective) =
    adjectives
    |> list.shuffle()
    |> list.first()

  let assert Ok(subject) =
    subjects
    |> list.shuffle()
    |> list.first()

  adjective <> " " <> subject
}

// --- Encoders and Decoders --- //

pub fn decode_message(
  params: List(#(String, String)),
) -> Result(Message, String) {
  case params {
    [#("action", "draw-card"), #("player", player)] -> {
      use player <- try(decode_player(player))
      Ok(Move(cf.DrawCard(player)))
    }

    [
      #("action", "play-card"),
      #("card_rank", rank),
      #("card_suit", suit),
      #("player", player),
      #("slot", slot),
    ] -> {
      use player <- try(decode_player(player))
      use slot <- try(decode_slot(slot))
      use suit <- try(decode_card_suit(suit))
      use rank <- try(decode_card_rank(rank))
      Ok(Move(cf.PlayCard(player, slot, cf.Card(rank, suit))))
    }

    [
      #("action", "select-card"),
      #("card_rank", rank),
      #("card_suit", suit),
      #("player", player),
    ] -> {
      use player <- try(decode_player(player))
      use suit <- try(decode_card_suit(suit))
      use rank <- try(decode_card_rank(rank))
      Ok(SelectCard(player, cf.Card(rank, suit)))
    }

    _other -> Error("Malformed message")
  }
}

fn encode_draw_card(player: cf.Player) -> Event {
  let action = "draw-card"
  let player = encode_player(player)
  let id = string.join([action, player], "-")

  Event(id: id, data: [#("action", action), #("player", player)])
}

fn encode_select_card(player: cf.Player, card: cf.Card) -> Event {
  let action = "select-card"
  let player = encode_player(player)
  let rank = encode_card_rank(card.rank)
  let suit = encode_card_suit(card.suit)
  let id = string.join([action, player, rank, suit], "-")

  Event(
    id: id,
    data: [
      #("action", "select-card"),
      #("player", player),
      #("card_rank", rank),
      #("card_suit", suit),
    ],
  )
}

fn encode_play_card(player: cf.Player, slot: cf.Slot, card: cf.Card) -> Event {
  let action = "play-card"
  let player = encode_player(player)
  let slot = encode_slot(slot)
  let id = string.join([action, player, slot], "-")

  Event(
    id: id,
    data: [
      #("action", "play-card"),
      #("player", player),
      #("slot", slot),
      #("card_rank", encode_card_rank(card.rank)),
      #("card_suit", encode_card_suit(card.suit)),
    ],
  )
}

const encoding_for_player = [
  #(cf.Player1, "player-1"),
  #(cf.Player2, "player-2"),
]

fn encode_player(value: cf.Player) -> String {
  encoding_for_player
  |> encode(value)
}

fn decode_player(value: String) -> Result(cf.Player, String) {
  encoding_for_player
  |> decode(value)
  |> result.replace_error("unable to decode player")
}

const encoding_for_slot = [
  #(cf.Slot1, "slot-1"),
  #(cf.Slot2, "slot-2"),
  #(cf.Slot3, "slot-3"),
  #(cf.Slot4, "slot-4"),
  #(cf.Slot5, "slot-5"),
  #(cf.Slot6, "slot-6"),
  #(cf.Slot7, "slot-7"),
  #(cf.Slot8, "slot-8"),
  #(cf.Slot9, "slot-9"),
]

fn encode_slot(value: cf.Slot) -> String {
  encoding_for_slot
  |> encode(value)
}

fn decode_slot(value: String) -> Result(cf.Slot, String) {
  encoding_for_slot
  |> decode(value)
  |> result.replace_error("unable to decode slot")
}

const encoding_for_card_rank = [
  #(1, "1"),
  #(2, "2"),
  #(3, "3"),
  #(4, "4"),
  #(5, "5"),
  #(6, "6"),
  #(7, "7"),
  #(8, "8"),
  #(9, "9"),
  #(10, "10"),
  #(11, "11"),
  #(12, "12"),
  #(13, "13"),
]

fn encode_card_rank(value: Int) -> String {
  encoding_for_card_rank
  |> encode(value)
}

fn decode_card_rank(value: String) -> Result(Int, String) {
  encoding_for_card_rank
  |> decode(value)
  |> result.replace_error("unable to decode card rank")
}

const encoding_for_card_suit = [
  #(cf.Spade, "spade"),
  #(cf.Heart, "heart"),
  #(cf.Diamond, "diamond"),
  #(cf.Club, "club"),
]

fn encode_card_suit(value: cf.Suit) -> String {
  encoding_for_card_suit
  |> encode(value)
}

fn decode_card_suit(value: String) -> Result(cf.Suit, String) {
  encoding_for_card_suit
  |> decode(value)
  |> result.replace_error("unable to decode card suit")
}

fn encode(encoding: List(#(x, y)), value: x) -> y {
  case key_find(encoding, value) {
    Ok(value) -> value
    Error(Nil) -> panic as "unable to encode value"
  }
}

fn decode(encoding: List(#(x, y)), value: y) -> Result(x, Nil) {
  encoding
  |> list.map(pair.swap)
  |> key_find(value)
}

fn key_find(pairs: List(#(x, y)), key: x) -> Result(y, Nil) {
  list.find_map(
    pairs,
    fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(pair.1)
      }
    },
  )
}
