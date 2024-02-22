import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/string
import luster/line_poker/game as g
import nakai/html
import nakai/html/attrs

// --- Elm-ish architecture with a Model and Init, Update, View callbacks --- //

pub type Message {
  SelectCard(g.Card)
  ToggleScoring
  Alert(g.Errors)
  UpdateGame(g.GameState)
}

pub type Model {
  Model(
    alert: Option(g.Errors),
    selected_card: Option(g.Card),
    toggle_scoring: Bool,
    gamestate: g.GameState,
  )
}

pub fn init(gamestate: g.GameState) -> Model {
  Model(
    alert: None,
    selected_card: None,
    toggle_scoring: True,
    gamestate: gamestate,
  )
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    SelectCard(card) -> {
      Model(..model, alert: None, selected_card: Some(card))
    }

    ToggleScoring -> {
      Model(..model, alert: None, toggle_scoring: !model.toggle_scoring)
    }

    Alert(error) -> {
      Model(..model, alert: Some(error))
    }

    UpdateGame(gamestate) -> {
      Model(..model, gamestate: gamestate)
    }
  }
}

pub fn view(model: Model) -> html.Node(a) {
  html.Fragment([
    game_info(model.gamestate, model.selected_card, model.alert),
    board(model.gamestate, model.selected_card),
    score_popup(model.gamestate, model.toggle_scoring),
  ])
}

// --- Helpers to build the view  --- //

fn game_info(
  state: g.GameState,
  selected_card: Option(g.Card),
  alert: Option(g.Errors),
) -> html.Node(a) {
  let #(_color, message) = case alert {
    Some(g.InvalidAction(_action)) -> #("red", "Invalid Action.")
    Some(g.NotCurrentPhase) -> #("yellow", "Not current phase.")
    Some(g.NotCurrentPlayer) -> #("yellow", "Not current player.")
    Some(g.NoCardInHand) -> #("yellow", "Card not in hand.")
    Some(g.EmptyDeck) -> #("green", "Deck already empty.")
    Some(g.MaxHandReached) -> #("green", "Hand at max.")
    Some(g.NotClaimableSlot) -> #("green", "Slot is not claimable.")
    Some(g.NotPlayableSlot) -> #("green", "Slot is not playable.")
    None -> #("purple", "")
  }

  let action = case
    g.current_turn(state),
    g.current_phase(state),
    selected_card
  {
    0, g.Draw, _selected -> "Initial Draw."
    _, g.Draw, _selected -> "Draw a card from pile."
    _, g.Play, Some(_) -> "Play a card from hand."
    _, g.Play, None -> "Select a card from hand."
    _, g.End, _ -> ""
  }

  let player = case
    g.current_turn(state),
    g.current_phase(state),
    g.current_player(state)
  {
    0, _phase, _player -> ""
    _, g.End, _player -> ""
    _, _phase, g.Player1 -> "Player 1,"
    _, _phase, g.Player2 -> "Player 2,"
  }

  html.section([attrs.class("player-info column center")], [
    html.div([attrs.class("player row center ")], [
      html.span_text([], message <> " " <> player <> " " <> action),
    ]),
  ])
}

fn board(state: g.GameState, selected_card: Option(g.Card)) -> html.Node(a) {
  html.section([attrs.class("play row evenly")], [
    html.div([attrs.class("column")], [
      html.div([attrs.class("s2")], []),
      html.div([attrs.class("s2 column center")], [deck(state, g.Player2)]),
      html.div([attrs.class("s6 column center")], [hand(state, g.Player2)]),
      html.div([attrs.class("s2")], []),
    ]),
    html.div([attrs.class("column")], [
      html.div([attrs.class("s2")], []),
      html.div([attrs.class("board s8 row")], [
        html.div([attrs.class("column center")], [
          score_columns(state, g.Player2),
        ]),
        html.div([attrs.class("column center")], [
          view_slots(state, g.Player2, selected_card),
        ]),
        html.div([attrs.class("column center")], [score_totals(state)]),
        html.div([attrs.class("column center")], [
          view_slots(state, g.Player1, selected_card),
        ]),
        html.div([attrs.class("column center")], [
          score_columns(state, g.Player1),
        ]),
      ]),
      html.div([attrs.class("s2")], []),
    ]),
    html.div([attrs.class("column")], [
      html.div([attrs.class("s2")], []),
      html.div([attrs.class("s6 column center")], [hand(state, g.Player1)]),
      html.div([attrs.class("s2 column center")], [deck(state, g.Player1)]),
      html.div([attrs.class("s2")], []),
    ]),
  ])
}

fn score_popup(state: g.GameState, toggle_scoring: Bool) -> html.Node(a) {
  case g.current_phase(state) {
    g.End -> {
      let dataset = dataset([#("event", encode_popup_toggle())])

      html.section([attrs.class("popup column center"), ..dataset], [
        case toggle_scoring {
          True -> html.div([attrs.class("row center")], [scores(state)])
          False -> html.Nothing
        },
      ])
    }

    _other -> {
      html.Nothing
    }
  }
}

fn hand(state: g.GameState, player: g.Player) -> html.Node(a) {
  let hand = g.player_hand(state, of: player)

  html.div(
    [attrs.class("hand column")],
    list.map(hand, fn(card) {
      click([#("event", encode_select_card(player, card))], card_front(card))
    }),
  )
}

fn deck(state: g.GameState, player: g.Player) -> html.Node(a) {
  let size = g.deck_size(state)

  click([#("event", encode_draw_card(player))], pile(size))
}

fn score_totals(state: g.GameState) -> html.Node(a) {
  let totals = g.score_totals(state)

  html.div([attrs.class("totals scores")], {
    use score <- list.map(totals)
    case score {
      #(Some(player), total) -> {
        let score = int.to_string(total)

        html.div([attrs.class("score" <> " " <> player_class(player))], [
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

fn score_columns(state: g.GameState, player: g.Player) -> html.Node(a) {
  let columns = g.score_columns(state)

  let scores = case player {
    g.Player1 -> list.map(columns, pair.first)
    g.Player2 -> list.map(columns, pair.second)
  }

  html.div([attrs.class("scores")], {
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
      [attrs.class("score" <> " " <> player_class(player))],
      list.concat([card, formation, flank]),
    )
  })
}

fn view_slots(
  state: g.GameState,
  player: g.Player,
  selected_card: Option(g.Card),
) -> html.Node(a) {
  let columns = g.columns(state, player)
  let class = attrs.class("slot" <> " " <> player_class(player))

  html.div([attrs.class("slots")], {
    use slot_column <- list.map(columns)
    let #(slot, column) = slot_column

    case selected_card {
      Some(card) ->
        click(
          [#("event", encode_play_card(player, slot, card))],
          html.div([class], list.map(column, fn(card) { card_front(card) })),
        )

      None -> html.div([class], list.map(column, fn(card) { card_front(card) }))
    }
  })
}

fn scores(state: g.GameState) -> html.Node(a) {
  let scores = g.score_columns(state)
  let total = g.score_total(state)

  let score_group =
    ScoreGroup(#(0, 0), #(0, 0), #(0, 0), #(0, 0), #(0, 0), #(0, 0), #(0, 0))

  let group = fn(group: ScoreGroup, score: g.Score) {
    case score.formation {
      g.StraightFlush -> {
        let #(count, bonus) = group.straight_flush
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, straight_flush: stats)
      }
      g.ThreeOfAKind -> {
        let #(count, bonus) = group.three_of_a_kind
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, three_of_a_kind: stats)
      }
      g.Straight -> {
        let #(count, bonus) = group.straight
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, straight: stats)
      }
      g.Flush -> {
        let #(count, bonus) = group.flush
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, flush: stats)
      }
      g.Pair -> {
        let #(count, bonus) = group.pair
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, pair: stats)
      }
      g.HighCard -> {
        let #(count, bonus) = group.highcard
        let stats = #(count + 1, bonus + score.bonus_formation)
        ScoreGroup(..group, highcard: stats)
      }
    }
  }

  let sum_score = fn(sum: Int, score: g.Score) { sum + score.score }
  let sum_form = fn(sum: Int, score: g.Score) { sum + score.bonus_formation }
  let sum_flank = fn(sum: Int, score: g.Score) { sum + score.bonus_flank }

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

  html.div([attrs.class("final-score sparkle")], [
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

fn card_front(card: g.Card) -> html.Node(a) {
  let utf = suit_utf(card.suit)
  let rank = rank_utf(card.rank)
  let color = suit_color(card.suit)

  html.div([attrs.class("card front " <> color)], [
    html.div([attrs.class("corner upper-left")], [
      html.p_text([], rank),
      html.p_text([], utf),
    ]),
    html.div([attrs.class("graphic")], [html.p_text([], utf)]),
    html.div([attrs.class("corner bottom-right")], [
      html.p_text([], rank),
      html.p_text([], utf),
    ]),
  ])
}

fn pile(size: Int) -> html.Node(a) {
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
  html.div([attrs.class("draw-pile")], list.repeat(card, count))
}

fn card_back() -> html.Node(a) {
  html.div([attrs.class("card back sparkle")], [])
}

fn suit_utf(suit: g.Suit) -> String {
  case suit {
    g.Spade -> "♠"
    g.Heart -> "♥"
    g.Diamond -> "♦"
    g.Club -> "♣"
  }
}

fn rank_utf(rank: Int) -> String {
  int.to_string(rank)
}

fn suit_color(suit: g.Suit) -> String {
  case suit {
    g.Spade -> "blue"
    g.Heart -> "red"
    g.Diamond -> "green"
    g.Club -> "purple"
  }
}

fn player_class(player: g.Player) -> String {
  case player {
    g.Player1 -> "player-1"
    g.Player2 -> "player-2"
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

fn group_table(group: ScoreGroup) -> html.Node(a) {
  let s = fn(x) { int.to_string(x) }

  let suit = fn(suit: g.Suit, rank: Int) -> html.Node(a) {
    let utf = suit_utf(suit)
    let color = suit_color(suit)
    let rank = int.to_string(rank)

    html.span_text([attrs.class(color)], rank <> utf <> " ")
  }

  let data = [
    #("Straight Flush", group.straight_flush.0, [
      suit(g.Spade, 3),
      suit(g.Spade, 2),
      suit(g.Spade, 1),
    ]),
    #("Three of Kind", group.three_of_a_kind.0, [
      suit(g.Spade, 7),
      suit(g.Diamond, 7),
      suit(g.Club, 7),
    ]),
    #("Straight", group.straight.0, [
      suit(g.Heart, 6),
      suit(g.Club, 5),
      suit(g.Spade, 4),
    ]),
    #("Flush", group.flush.0, [
      suit(g.Heart, 8),
      suit(g.Heart, 4),
      suit(g.Heart, 2),
    ]),
    #("Pair", group.pair.0, [suit(g.Club, 4), suit(g.Diamond, 4)]),
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
        html.td_text([], "Card points"),
        html.td_text([], int.to_string(card)),
      ]),
      html.tr([], [
        html.td_text([], "Formation points"),
        html.td_text([], int.to_string(formation)),
      ]),
      html.tr([], [
        html.td_text([], "Flank points"),
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

fn winner(total: #(Option(g.Player), Int)) -> html.Node(a) {
  let total = case total {
    #(Some(g.Player1), total) -> #("Player 1!", int.to_string(total))
    #(Some(g.Player2), total) -> #("Player 2!", int.to_string(total))
    #(None, total) -> #("DRAW", int.to_string(total))
  }

  html.div([attrs.class("score-winner")], [
    html.h2_text([], total.0),
    html.h3_text([], total.1 <> " points"),
  ])
}

// --- This code encodes "clicks" into the HTML --- //

fn click(
  params: List(#(String, BitArray)),
  markup: html.Node(a),
) -> html.Node(a) {
  let dataset = dataset(params)
  html.div(dataset, [markup])
}

fn dataset(params: List(#(String, BitArray))) -> List(attrs.Attr(a)) {
  let to_string = fn(bits) {
    let assert Ok(string) = bit_array.to_string(bits)
    string
  }

  params
  |> list.map(fn(param) { #(param.0, to_string(param.1)) })
  |> list.map(data_attr)
}

fn data_attr(param: #(String, String)) -> attrs.Attr(a) {
  attrs.Attr(name: "data-" <> param.0, value: param.1)
}

fn encode_draw_card(player: g.Player) -> BitArray {
  let player = encode_player(player)
  <<"draw-card":utf8, player:bits>>
}

fn encode_play_card(player: g.Player, slot: g.Slot, card: g.Card) -> BitArray {
  let player = encode_player(player)
  let slot = encode_slot(slot)
  let rank = encode_rank(card.rank)
  let suit = encode_suit(card.suit)
  <<"play-card":utf8, player:bits, slot:bits, suit:bits, rank:bits>>
}

fn encode_select_card(player: g.Player, card: g.Card) -> BitArray {
  let _player = encode_player(player)
  let suit = encode_suit(card.suit)
  let rank = encode_rank(card.rank)
  //<<"select-card":utf8, player:bits, suit:bits, rank:bits>>
  <<"select-card":utf8, suit:bits, rank:bits>>
}

fn encode_popup_toggle() -> BitArray {
  <<"popup-toggle":utf8>>
}

fn encode_player(player: g.Player) -> BitArray {
  case player {
    g.Player1 -> <<"p1":utf8>>
    g.Player2 -> <<"p2":utf8>>
  }
}

fn encode_slot(slot: g.Slot) -> BitArray {
  case slot {
    g.Slot1 -> <<"1":utf8>>
    g.Slot2 -> <<"2":utf8>>
    g.Slot3 -> <<"3":utf8>>
    g.Slot4 -> <<"4":utf8>>
    g.Slot5 -> <<"5":utf8>>
    g.Slot6 -> <<"6":utf8>>
    g.Slot7 -> <<"7":utf8>>
    g.Slot8 -> <<"8":utf8>>
    g.Slot9 -> <<"9":utf8>>
  }
}

fn encode_rank(rank: Int) -> BitArray {
  let string =
    rank
    |> int.to_string()
    |> string.pad_left(2, "0")

  <<string:utf8>>
}

fn encode_suit(suit: g.Suit) -> BitArray {
  case suit {
    g.Spade -> <<"♠":utf8>>
    g.Heart -> <<"♥":utf8>>
    g.Diamond -> <<"♦":utf8>>
    g.Club -> <<"♣":utf8>>
  }
}
