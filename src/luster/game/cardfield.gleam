import gleam/int
import gleam/list
import gleam/map.{type Map}
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result.{try}

// IDEA: Add rummy like card play with discards
// IDEA: Create basic computer players 
// IDEA: Remove 3 card limit for colums, have a diff trigger for countdown
// IDEA: Counter mechanic, being able to "steal" a card and place elsewhere
// IDEA: Add sprites with animations instead of ranks

pub opaque type GameState {
  GameState(
    phase: Phase,
    board: Board,
    sequence: List(Player),
    scoring: Scoring,
  )
}

pub type Phase {
  FillHandPhase
  PlayCardPhase1
  PlayCardPhase2
  PlayCardPhase3
  ReplentishPhase1
  ReplentishPhase2
  ReplentishPhase3
  EndPhase
}

pub opaque type Board {
  Board(
    deck: List(Card),
    hands: Map(Player, List(Card)),
    battleline: Line(Battle),
  )
}

pub type Player {
  Player1
  Player2
}

type Line(piece) =
  Map(Slot, piece)

// TODO: Win condition
// * When player cannot draw from deck we go to scoring
//   - Flank Bonus: 
//     +3 for adjacent winning tiles
// TODO: A slot should probably contain a set of cards
// Data structure should bi a list of ordered slots 
// that contains a list of cards each one.
pub type Slot {
  Slot1
  Slot2
  Slot3
  Slot4
  Slot5
  Slot6
  Slot7
  Slot8
  Slot9
}

pub type Card {
  Card(rank: Int, suit: Suit)
}

pub type Suit {
  Spade
  Heart
  Diamond
  Club
}

type Battle =
  Map(Player, Column)

type Column =
  List(Card)

type Formation {
  ThreeSuitsInSequence
  ThreeRanks
  ThreeInSequence
  ThreeSuits
  HighCard
}

pub type Scoring {
  Scoring(
    columns: List(#(Score, Score)),
    totals: List(#(Option(Player), Int)),
    total: #(Option(Player), Int),
  )
}

pub type Score {
  Score(card_score: Int, formation_bonus: Int)
}

pub type Errors {
  NotCurrentPhase
  NotCurrentPlayer
  EmptyDeck
  MaxHandReached
  NoCardInHand
  NotPlayableSlot
  NotClaimableSlot
}

const max_hand_size = 8

const slots = [Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9]

const ranks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

const suits = [Spade, Heart, Diamond, Club]

// --- GameState API --- //

/// Initializes a new gamestate.
pub fn new() -> GameState {
  GameState(
    phase: FillHandPhase,
    board: new_board(),
    sequence: list.shuffle([Player1, Player2]),
    scoring: new_scoring(),
  )
}

pub type Action {
  DrawCard(player: Player)
  PlayCard(player: Player, slot: Slot, card: Card)
}

/// Modifies the game state by applying an action.
pub fn next(state: GameState, action: Action) -> Result(GameState, Errors) {
  let current = first(state.sequence)

  case state.phase, action {
    FillHandPhase, DrawCard(player) -> {
      state
      |> draw_card(player)
      |> result.map(fn(state) {
        case are_hands_full(state.board.hands) {
          True -> GameState(..state, phase: PlayCardPhase1)
          False -> state
        }
      })
    }

    PlayCardPhase1, PlayCard(player, slot, card) if player == current -> {
      state
      |> play_card(player, slot, card)
      |> result.map(fn(state) {
        GameState(..state, scoring: calculate_scoring(state.board.battleline))
      })
      |> result.map(fn(state) { GameState(..state, phase: PlayCardPhase2) })
    }

    PlayCardPhase2, PlayCard(player, slot, card) if player == current -> {
      state
      |> play_card(player, slot, card)
      |> result.map(fn(state) {
        GameState(..state, scoring: calculate_scoring(state.board.battleline))
      })
      |> result.map(fn(state) { GameState(..state, phase: PlayCardPhase3) })
    }

    PlayCardPhase3, PlayCard(player, slot, card) if player == current -> {
      state
      |> play_card(player, slot, card)
      |> result.map(fn(state) {
        GameState(..state, scoring: calculate_scoring(state.board.battleline))
      })
      |> result.map(fn(state) {
        case deck_size(state) {
          size if size > 0 -> GameState(..state, phase: ReplentishPhase1)
          _zero -> GameState(..state, phase: EndPhase)
        }
      })
    }

    ReplentishPhase1, DrawCard(player) if player == current -> {
      state
      |> draw_card(player)
      |> result.map(fn(state) { GameState(..state, phase: ReplentishPhase2) })
    }

    ReplentishPhase2, DrawCard(player) if player == current -> {
      state
      |> draw_card(player)
      |> result.map(fn(state) { GameState(..state, phase: ReplentishPhase3) })
    }

    ReplentishPhase3, DrawCard(player) if player == current -> {
      state
      |> draw_card(player)
      |> result.map(fn(state) { GameState(..state, phase: PlayCardPhase1) })
      |> result.map(fn(state) {
        GameState(..state, sequence: rotate(state.sequence))
      })
    }

    _, _ -> {
      Error(NotCurrentPhase)
    }
  }
}

// --- Introspection API --- //

///Retrieves the current deck size from the 
pub fn deck_size(state: GameState) -> Int {
  list.length(state.board.deck)
}

/// Retrieves a player's full hand
pub fn player_hand(state: GameState, of player: Player) -> List(Card) {
  get(state.board.hands, player)
}

/// Retrieves the current phase
pub fn current_phase(state: GameState) -> Phase {
  state.phase
}

/// Retrieves the current player
pub fn current_player(state: GameState) -> Player {
  first(state.sequence)
}

/// Retrieves battle columns from a player in the right order.
pub fn columns(state: GameState, of player: Player) -> List(#(Slot, Column)) {
  let battleline = state.board.battleline

  slots
  |> list.map(fn(slot) {
    let battle = get(battleline, slot)
    #(slot, battle)
  })
  |> list.map(fn(slot_battle) {
    let #(slot, battle) = slot_battle
    let column = get(battle, player)
    #(slot, column)
  })
}

/// Retrieves a list of slots available for playing a card.
pub fn available_plays(state: GameState, of player: Player) -> List(Slot) {
  let battleline = state.board.battleline

  use slot <- list.filter(slots)
  let battle = get(battleline, slot)
  let column = get(battle, player)

  column
  |> available_play()
  |> result.is_ok()
}

pub fn score_columns(state: GameState) {
  state.scoring.columns
}

pub fn score_totals(state: GameState) {
  state.scoring.totals
}

pub fn score_total(state: GameState) {
  state.scoring.total
}

// /// Goes through a player's columns and checks for a breakthrough win.
// fn is_breakthrough(board: Board, of player: Player) -> Bool {
//   let flags = board.flags
// 
//   slots
//   |> list.map(fn(slot) { get(flags, slot) })
//   |> list.window(3)
//   |> list.any(fn(claims) { list.all(claims, fn(flag) { flag == Some(player) }) })
// }

// /// Goes through a player's columns and checks for an envelopment win.
// fn is_envelopment(board: Board, of player: Player) -> Bool {
//   board.flags
//   |> map.filter(fn(_slot, flag) { flag == Some(player) })
//   |> map.size() >= 5
// }

// --- Function Helpers --- // 

fn new_scoring() -> Scoring {
  Scoring(
    columns: list.map(slots, fn(_) { #(Score(0, 0), Score(0, 0)) }),
    totals: list.map(slots, fn(_) { figure_player(0) }),
    total: #(None, 0),
  )
}

fn new_board() -> Board {
  Board(
    deck: new_deck(),
    battleline: new_line(
      map.new()
      |> map.insert(Player1, [])
      |> map.insert(Player2, []),
    ),
    hands: map.new()
    |> map.insert(Player1, [])
    |> map.insert(Player2, []),
  )
}

fn new_deck() -> List(Card) {
  list.shuffle({
    use rank <- list.flat_map(ranks)
    use suit <- list.map(suits)
    Card(rank: rank, suit: suit)
  })
}

fn new_line(of piece: piece) -> Line(piece) {
  slots
  |> list.map(fn(slot) { #(slot, piece) })
  |> map.from_list()
}

fn draw_card(state: GameState, of player: Player) -> Result(GameState, Errors) {
  let GameState(board: board, ..) = state
  let hand = get(board.hands, player)
  use #(card, deck) <- try(draw_card_from_deck(board.deck))
  use new_hand <- try(add_card_to_hand(hand, card))
  let hands = map.insert(board.hands, player, new_hand)
  let board = Board(..board, deck: deck, hands: hands)
  let state = GameState(..state, board: board)
  Ok(state)
}

fn draw_card_from_deck(deck: List(Card)) -> Result(#(Card, List(Card)), Errors) {
  deck
  |> list.pop(fn(_) { True })
  |> result.replace_error(EmptyDeck)
}

fn add_card_to_hand(hand: List(Card), card: Card) -> Result(List(Card), Errors) {
  let new_hand = list.append(hand, [card])

  case list.length(new_hand) > max_hand_size {
    False -> Ok(new_hand)
    True -> Error(MaxHandReached)
  }
}

fn card_score(column: Column) -> Int {
  column
  |> list.map(fn(card) { card.rank })
  |> list.fold(0, fn(sum, rank) { sum + rank })
}

fn formation_score(column: Column) -> Int {
  case formation(column) {
    ThreeSuitsInSequence -> 7
    ThreeRanks -> 5
    ThreeInSequence -> 3
    ThreeSuits -> 1
    HighCard -> 0
  }
}

fn formation(column: Column) -> Formation {
  case list.sort(column, by: rank_compare) {
    [card_a, card_b, card_c] -> formation_type(card_a, card_b, card_c)
    _other -> HighCard
  }
}

fn rank_compare(card_a: Card, card_b: Card) -> Order {
  let Card(rank: a, ..) = card_a
  let Card(rank: b, ..) = card_b
  int.compare(a, b)
}

fn formation_type(card_a: Card, card_b: Card, card_c: Card) -> Formation {
  let Card(suit: sa, rank: ra) = card_a
  let Card(suit: sb, rank: rb) = card_b
  let Card(suit: sc, rank: rc) = card_c

  let same_suits = sa == sb && sb == sc
  let same_ranks = ra == rb && rb == rc
  let in_sequence = { ra + 1 == rb } && { rb + 1 == rc }

  case same_suits, same_ranks, in_sequence {
    True, False, True -> ThreeSuitsInSequence
    False, True, False -> ThreeRanks
    False, False, True -> ThreeInSequence
    True, False, False -> ThreeSuits
    False, False, False -> HighCard
  }
}

fn play_card(
  state: GameState,
  of player: Player,
  at slot: Slot,
  with card: Card,
) -> Result(GameState, Errors) {
  let GameState(board: board, ..) = state
  let hand = get(board.hands, player)
  let battle = get(board.battleline, slot)
  let column = get(battle, player)

  use #(card, hand) <- try(pick_card(from: hand, where: card))
  use column <- try(available_play(is: column))

  let hands = map.insert(board.hands, player, hand)

  let column = list.append(column, [card])
  let battle = map.insert(battle, player, column)
  let battleline = map.insert(board.battleline, slot, battle)

  let board = Board(..board, hands: hands, battleline: battleline)
  let state = GameState(..state, board: board)

  Ok(state)
}

fn pick_card(
  from hand: List(Card),
  where card: Card,
) -> Result(#(Card, List(Card)), Errors) {
  hand
  |> list.pop(fn(c) { c == card })
  |> result.replace_error(NoCardInHand)
}

fn available_play(is column: Column) -> Result(Column, Errors) {
  case column {
    [_, _, _] -> Error(NotPlayableSlot)
    column -> Ok(column)
  }
}

fn rotate(list: List(x)) -> List(x) {
  let assert [head, ..tail] = list
  list.append(tail, [head])
}

fn first(list: List(x)) -> x {
  let assert [head, ..] = list
  head
}

fn are_hands_full(hands: Map(Player, List(Card))) -> Bool {
  let p1_hand = get(hands, Player1)
  let p2_hand = get(hands, Player2)

  list.length(p1_hand) >= max_hand_size && list.length(p2_hand) >= max_hand_size
}

fn calculate_scoring(battleline: Line(Battle)) -> Scoring {
  let columns = calculate_columns(battleline)
  let totals = calculate_totals(columns)
  let total = calculate_total(totals)

  Scoring(
    columns: columns,
    totals: list.map(totals, figure_player),
    total: figure_player(total),
  )
}

fn calculate_columns(battleline: Line(Battle)) -> List(#(Score, Score)) {
  slots
  |> list.map(fn(slot) {
    let battle = get(battleline, slot)
    let column_p1 = get(battle, Player1)
    let column_p2 = get(battle, Player2)

    let card_p1 = card_score(column_p1)
    let bonus_p1 = formation_score(column_p1)
    let card_p2 = card_score(column_p2)
    let bonus_p2 = formation_score(column_p2)

    #(
      Score(card_score: card_p1, formation_bonus: bonus_p1),
      Score(card_score: card_p2, formation_bonus: bonus_p2),
    )
  })
}

fn calculate_totals(scores: List(#(Score, Score))) -> List(Int) {
  let totals =
    list.map(
      scores,
      fn(score) {
        let #(score_p1, score_p2) = score

        let score_p1 = score_p1.card_score + score_p1.formation_bonus
        let score_p2 = score_p2.card_score + score_p2.formation_bonus

        score_p1 - score_p2
      },
    )

  // TODO: Review how to do retroactive scoring
  //let assert [first, ..] = totals
  //let right_support = right_support_score(totals)
  //let totals = [first, ..right_support]

  //let assert [last, ..] = list.reverse(totals)
  //let left_support = left_support_score(totals)
  //let totals = list.append(left_support, [last])

  totals
}

fn right_support_score(scores: List(Int)) -> List(Int) {
  scores
  |> list.window_by_2()
  |> list.map(fn(pair) {
    case pair {
      #(left, right) if left > 0 && right > 0 -> right + 1
      #(left, right) if left < 0 && right < 0 -> right - 1
      _other -> 0
    }
  })
}

fn left_support_score(scores: List(Int)) -> List(Int) {
  scores
  |> list.reverse()
  |> right_support_score()
  |> list.reverse()
}

fn calculate_total(scores: List(Int)) -> Int {
  list.fold(scores, 0, fn(total, score) { total + score })
}

fn figure_player(score: Int) -> #(Option(Player), Int) {
  case score {
    score if score > 0 -> #(Some(Player1), score)
    score if score < 0 -> #(Some(Player2), int.absolute_value(score))
    0 -> #(None, 0)
  }
}

fn get(map: Map(key, value), key: key) -> value {
  let assert Ok(value) = map.get(map, key)
  value
}
