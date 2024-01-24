import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/pair
import gleam/list
import gleam/dict.{type Dict}
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
    selected_card: Dict(cf.Player, Option(cf.Card)),
    toggle_scoring: Bool,
    gamestate: cf.GameState,
  )
}

type Event {
  Event(id: String, data: List(#(String, String)))
}

pub type Message {
  SelectCard(player: cf.Player, card: cf.Card)
  Move(action: cf.Action)
  ToggleScoring
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
    selected_card: dict.new()
    |> dict.insert(cf.Player1, None)
    |> dict.insert(cf.Player2, None),
    toggle_scoring: True,
    gamestate: cf.new(),
  )
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    SelectCard(player, card) -> {
      case cf.current_phase(model.gamestate) {
        cf.Play -> {
          let alert = Some(Info("Play card on a column"))
          let selected_card =
            dict.insert(model.selected_card, player, Some(card))
          Model(..model, alert: alert, selected_card: selected_card)
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

    ToggleScoring -> {
      Model(..model, toggle_scoring: !model.toggle_scoring)
    }
  }
}

pub fn view(model: Model) -> html.Node(a) {
  let phase = cf.current_phase(model.gamestate)

  let end_game_scoring = case model.toggle_scoring {
    True -> end_game_scoring(model.gamestate)
    False -> html.Nothing
  }

  let toggle_event = encode_toggle_scoring()

  html.Fragment([
    form(toggle_event, popup(phase == cf.End, end_game_scoring)),
    view_game_info(model.gamestate),
    view_alert(model.alert),
    html.div([attrs.class("board")], [
      html.div([attrs.class("deck")], []),
      html.div([attrs.class("field")], [
        view_hand(model.gamestate, cf.Player2),
        view_score_columns(model.gamestate, cf.Player2),
        view_slots(model, cf.Player2),
        view_score_totals(model.gamestate),
        view_slots(model, cf.Player1),
        view_score_columns(model.gamestate, cf.Player1),
        view_hand(model.gamestate, cf.Player1),
      ]),
      view_card_pile(model.gamestate),
    ]),
  ])
}

// --- View board segments --- //

fn view_game_info(state: cf.GameState) -> html.Node(a) {
  let size =
    cf.deck_size(state)
    |> int.to_string()

  let phase = case cf.current_turn(state), cf.current_phase(state) {
    0, cf.Draw -> "Initial Draw"
    _, cf.Draw -> "Draw Card Phase"
    _, cf.Play -> "Play Card Phase"
    _, cf.End -> "Game!"
  }

  let player = case cf.current_player(state) {
    cf.Player1 -> "Player 1"
    cf.Player2 -> "Player 2"
  }

  html.section([attrs.id("alert-message"), attrs.class("alerts")], [
    html.div([], [
      html.span_text([], "Deck size: " <> size),
      html.span_text([], "Phase: " <> phase),
      html.span_text([], "Current player: " <> player),
    ]),
  ])
}

fn view_alert(message: Option(Alert)) -> html.Node(a) {
  case message {
    Some(a) -> {
      html.section([attrs.id("alert-message"), attrs.class("alerts")], [
        alert(a),
      ])
    }

    None -> {
      html.Fragment([])
    }
  }
}

fn view_card_pile(state: cf.GameState) -> html.Node(a) {
  let size = cf.deck_size(state)
  let p1_event = encode_draw_card(cf.Player1)
  let p2_event = encode_draw_card(cf.Player2)

  html.div([attrs.class("deck")], [
    html.section([attrs.class("draw-pile")], [form(p2_event, draw_deck(size))]),
    html.section([attrs.class("draw-pile")], [form(p1_event, draw_deck(size))]),
  ])
}

fn view_score_totals(state: cf.GameState) -> html.Node(a) {
  let totals = cf.score_totals(state)

  html.section([attrs.class("scores")], {
    use score <- list.map(totals)
    case score {
      #(Some(player), total) -> {
        let player = encode_player(player)
        let score = int.to_string(total)

        html.div([attrs.class("score" <> " " <> player)], [
          html.span_text([], score),
        ])
      }

      #(None, total) -> {
        let score = int.to_string(total)

        html.div([attrs.class("score")], [html.span_text([], score)])
      }
    }
  })
}

fn view_score_columns(state: cf.GameState, player: cf.Player) -> html.Node(a) {
  let columns = cf.score_columns(state)

  let scores = case player {
    cf.Player1 -> list.map(columns, pair.first)
    cf.Player2 -> list.map(columns, pair.second)
  }

  let player = encode_player(player)

  html.section([attrs.class("scores")], {
    use score <- list.map(scores)
    let card = int.to_string(score.score)
    let formation = int.to_string(score.bonus_formation)
    let flank = int.to_string(score.bonus_flank)

    let card = [html.span_text([attrs.class("unit")], card)]

    let formation = case score.bonus_formation {
      0 -> []

      _ -> [
        html.span_text([attrs.class("formation")], " + "),
        html.span_text([attrs.class("formation")], formation),
      ]
    }

    let flank = case score.bonus_flank {
      0 -> []

      _ -> [
        html.span_text([attrs.class("flank")], " + "),
        html.span_text([attrs.class("flank")], flank),
      ]
    }

    html.div(
      [attrs.class("score" <> " " <> player)],
      list.concat([card, formation, flank]),
    )
  })
}

fn view_hand(state: cf.GameState, player: cf.Player) -> html.Node(a) {
  let hand = cf.player_hand(state, of: player)

  html.section(
    [attrs.class("hand")],
    list.map(hand, fn(card) {
      let event = encode_select_card(player, card)
      form(event, card_front(card))
    }),
  )
}

fn view_slots(model: Model, player: cf.Player) -> html.Node(a) {
  let columns = cf.columns(model.gamestate, player)
  let assert Ok(selected_card) = dict.get(model.selected_card, player)
  let player_class = encode_player(player)

  html.section([attrs.class("slots")], {
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
  })
}

// --- View board components --- //

fn card_front(card: cf.Card) -> html.Node(a) {
  let utf = suit_utf(card.suit)
  let color = suit_color(card.suit)

  let rank = int.to_string(card.rank)

  html.div([attrs.class("card front clouds " <> color)], [
    html.div([attrs.class("upper-left")], [
      html.p_text([], rank),
      html.p_text([], utf),
    ]),
    html.div([attrs.class("graphic")], [html.p_text([], utf)]),
    html.div([attrs.class("bottom-right")], [
      html.p_text([], rank),
      html.p_text([], utf),
    ]),
  ])
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
    _ -> 0
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

  html.div([attrs.class("alert " <> color)], [html.span_text([], alert.message)])
}

fn to_alert(error: cf.Errors) -> Alert {
  case error {
    cf.InvalidAction(_) -> Bad("Invalid Action")
    cf.NotCurrentPhase -> Warn("Not current phase")
    cf.NotCurrentPlayer -> Warn("Not current player")
    cf.NoCardInHand -> Warn("Card not in hand")
    cf.EmptyDeck -> Info("Deck already empty")
    cf.MaxHandReached -> Info("Hand at max")
    cf.NotClaimableSlot -> Info("Slot is not claimable")
    cf.NotPlayableSlot -> Info("Slot is not playable")
  }
}

fn suit_utf(suit: cf.Suit) -> String {
  case suit {
    cf.Spade -> "♠"
    cf.Heart -> "♥"
    cf.Diamond -> "♦"
    cf.Club -> "♣"
  }
}

fn suit_color(suit: cf.Suit) -> String {
  case suit {
    cf.Spade -> "blue"
    cf.Heart -> "red"
    cf.Diamond -> "green"
    cf.Club -> "purple"
  }
}

type ScoreGroup {
  ScoreGroup(
    straight_flush: #(Int, Int),
    three_of_a_kind: #(Int, Int),
    straight: #(Int, Int),
    flush: #(Int, Int),
    pair: #(Int, Int),
    flank_bonus: #(Int, Int),
    highcard: #(Int, Int),
  )
}

fn end_game_scoring(state: cf.GameState) -> html.Node(a) {
  let scores = cf.score_columns(state)
  let total = cf.score_total(state)

  let score_group =
    ScoreGroup(#(0, 0), #(0, 0), #(0, 0), #(0, 0), #(0, 0), #(0, 0), #(0, 0))

  let group = fn(group: ScoreGroup, score: cf.Score) {
    case score.formation {
      cf.StraightFlush -> {
        let #(count, bonus) = group.straight_flush
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, straight_flush: stats)
      }
      cf.ThreeOfAKind -> {
        let #(count, bonus) = group.three_of_a_kind
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, three_of_a_kind: stats)
      }
      cf.Straight -> {
        let #(count, bonus) = group.straight
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, straight: stats)
      }
      cf.Flush -> {
        let #(count, bonus) = group.flush
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, flush: stats)
      }
      cf.Pair -> {
        let #(count, bonus) = group.pair
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, pair: stats)
      }
      cf.HighCard -> {
        let #(count, bonus) = group.highcard
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, highcard: stats)
      }
    }
  }

  let sum_score = fn(sum: Int, score: cf.Score) { sum + score.score }
  let sum_form = fn(sum: Int, score: cf.Score) { sum + score.bonus_formation }
  let sum_flank = fn(sum: Int, score: cf.Score) { sum + score.bonus_flank }

  let p1_scores = list.map(scores, pair.first)
  let p1_score_group = list.fold(p1_scores, score_group, group)
  let p1_card_total = list.fold(p1_scores, 0, sum_score)
  let p1_form_total = list.fold(p1_scores, 0, sum_form)
  let p1_flank_total = list.fold(p1_scores, 0, sum_flank)

  let p2_scores = list.map(scores, pair.second)
  let p2_score_group = list.fold(p2_scores, score_group, group)
  let p2_card_total = list.fold(p2_scores, 0, sum_score)
  let p2_form_total = list.fold(p2_scores, 0, sum_form)
  let p2_flank_total = list.fold(p2_scores, 0, sum_flank)

  html.div([attrs.class("sparkle")], [
    html.Fragment([
      html.div([attrs.class("score-winner")], [html.h1_text([], "Game!")]),
      html.div([attrs.class("score-group")], [
        html.div([], [
          group_table(p1_score_group),
          html.Element("hr", [], []),
          subtotals_table(p1_card_total, p1_form_total, p1_flank_total),
          html.Element("hr", [], []),
          totals_table(p1_card_total + p1_form_total + p1_flank_total),
        ]),
        html.div([], [
          group_table(p2_score_group),
          html.Element("hr", [], []),
          subtotals_table(p2_card_total, p2_form_total, p2_flank_total),
          html.Element("hr", [], []),
          totals_table(p2_card_total + p2_form_total + p2_flank_total),
        ]),
      ]),
      winner(total),
    ]),
  ])
}

fn group_table(group: ScoreGroup) -> html.Node(a) {
  let s = fn(x) { int.to_string(x) }

  let suit = fn(suit: cf.Suit, rank: Int) -> html.Node(a) {
    let utf = suit_utf(suit)
    let color = suit_color(suit)
    let rank = int.to_string(rank)

    html.span_text([attrs.class(color)], rank <> utf <> " ")
  }

  let data = [
    #("Straight Flush", group.straight_flush.0, [
      suit(cf.Spade, 3),
      suit(cf.Spade, 2),
      suit(cf.Spade, 1),
    ]),
    #("Three of Kind", group.three_of_a_kind.0, [
      suit(cf.Spade, 7),
      suit(cf.Diamond, 7),
      suit(cf.Club, 7),
    ]),
    #("Straight", group.straight.0, [
      suit(cf.Heart, 6),
      suit(cf.Club, 5),
      suit(cf.Spade, 4),
    ]),
    #("Flush", group.flush.0, [
      suit(cf.Heart, 8),
      suit(cf.Heart, 4),
      suit(cf.Heart, 2),
    ]),
    #("Pair", group.pair.0, [suit(cf.Club, 4), suit(cf.Diamond, 4)]),
  ]

  html.table([], [
    html.tbody([], {
      use #(name, count, suit) <- list.map(data)
      html.tr([], [
        html.td([], [html.div_text([], name), html.div([], suit)]),
        html.td_text([], "x" <> s(count)),
      ])
    }),
  ])
}

fn subtotals_table(card: Int, formation: Int, flank: Int) -> html.Node(a) {
  html.table([], [
    html.tbody([], [
      html.tr([], [
        html.td_text([], "Cards Played"),
        html.td_text([], int.to_string(card)),
      ]),
      html.tr([], [
        html.td_text([], "Formation"),
        html.td_text([], int.to_string(formation)),
      ]),
      html.tr([], [
        html.td_text([], "Flank"),
        html.td_text([], int.to_string(flank)),
      ]),
    ]),
  ])
}

fn totals_table(total: Int) -> html.Node(a) {
  html.table([], [
    html.tbody([], [
      html.tr([], [
        html.td_text([], "Total"),
        html.td_text([], int.to_string(total)),
      ]),
    ]),
  ])
}

fn winner(total: #(Option(cf.Player), Int)) -> html.Node(a) {
  let total = case total {
    #(Some(cf.Player1), total) -> #("Player 1!", int.to_string(total))
    #(Some(cf.Player2), total) -> #("Player 2!", int.to_string(total))
    #(None, total) -> #("DRAW", int.to_string(total))
  }

  html.div([attrs.class("score-winner")], [
    html.h2_text([], total.0),
    html.h3_text([], total.1),
  ])
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

fn popup(display: Bool, markup: html.Node(a)) -> html.Node(a) {
  case display {
    True -> html.div([attrs.class("popup")], [markup])
    False -> html.Nothing
  }
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
      #("player", player),
      #("slot", slot),
      #("card_rank", rank),
      #("card_suit", suit),
    ] -> {
      use player <- try(decode_player(player))
      use slot <- try(decode_slot(slot))
      use suit <- try(decode_card_suit(suit))
      use rank <- try(decode_card_rank(rank))
      Ok(Move(cf.PlayCard(player, slot, cf.Card(rank, suit))))
    }

    [
      #("action", "select-card"),
      #("player", player),
      #("card_rank", rank),
      #("card_suit", suit),
    ] -> {
      use player <- try(decode_player(player))
      use suit <- try(decode_card_suit(suit))
      use rank <- try(decode_card_rank(rank))
      Ok(SelectCard(player, cf.Card(rank, suit)))
    }

    [#("action", "toggle-scoring")] -> {
      Ok(ToggleScoring)
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

  Event(id: id, data: [
    #("action", "select-card"),
    #("player", player),
    #("card_rank", rank),
    #("card_suit", suit),
  ])
}

fn encode_play_card(player: cf.Player, slot: cf.Slot, card: cf.Card) -> Event {
  let action = "play-card"
  let player = encode_player(player)
  let slot = encode_slot(slot)
  let id = string.join([action, player, slot], "-")

  Event(id: id, data: [
    #("action", "play-card"),
    #("player", player),
    #("slot", slot),
    #("card_rank", encode_card_rank(card.rank)),
    #("card_suit", encode_card_suit(card.suit)),
  ])
}

fn encode_toggle_scoring() -> Event {
  let action = "toggle-scoring"

  Event(id: action, data: [#("action", action)])
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
  list.find_map(pairs, fn(pair) {
    case pair.0 == key {
      True -> Ok(pair.1)
      False -> Error(pair.1)
    }
  })
}
