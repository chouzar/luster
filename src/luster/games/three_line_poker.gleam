import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result.{try}

pub const max_hand_size = 8

pub const plays_per_turn = 4

const ranks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

const suits = [Spade, Heart, Diamond, Club]

const straight_flush = 23

const three_of_a_kind = 17

const straight = 11

const flush = 5

const pair = 3

const highcard = 0

const flank_bonus = 5

pub type Message {
  DrawCard(player: Player)
  PlayCard(player: Player, slot: Slot, card: Card)
}

pub opaque type GameState {
  GameState(
    turn: Int,
    phase: Phase,
    board: Board,
    sequence: List(Player),
    total_score: TotalScore,
  )
}

pub type Phase {
  Draw
  Play
  End
}

pub opaque type Board {
  Board(
    deck: List(Card),
    hands: Dict(Player, List(Card)),
    battleline: Line(Battle),
  )
}

pub type Player {
  Player1
  Player2
}

type Line(piece) =
  Dict(Slot, piece)

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
  Dict(Player, Column)

type Column =
  List(Card)

pub type Formation {
  StraightFlush
  ThreeOfAKind
  Straight
  Flush
  Pair
  HighCard
}

pub type TotalScore {
  TotalScore(
    columns: List(#(Score, Score)),
    totals: List(#(Option(Player), Int)),
    total: #(Option(Player), Int),
  )
}

pub type Score {
  Score(
    score: Int,
    bonus_formation: Int,
    bonus_flank: Int,
    formation: Formation,
  )
}

pub type Errors {
  InvalidAction(Message)
  NotCurrentPhase
  NotCurrentPlayer
  EmptyDeck
  MaxHandReached
  NoCardInHand
  NotPlayableSlot
  NotClaimableSlot
}

// --- GameState API --- //

/// Initializes a new gamestate.
pub fn new() -> GameState {
  GameState(
    turn: 0,
    phase: Draw,
    board: new_board(),
    sequence: [Player1, Player2],
    total_score: new_total_score(),
  )
}

/// Modifies the game state by applying an action.
pub fn next(state: GameState, action: Message) -> Result(GameState, Errors) {
  case state.phase, action {
    Draw, DrawCard(player) -> {
      Ok(state)
      |> result.then(fn(state) {
        draw_card(state.board, player)
        |> result.map(fn(board) { GameState(..state, board: board) })
      })
      |> result.map(fn(state) {
        case are_hands_full(state.board.hands) {
          True ->
            GameState(
              ..state,
              turn: state.turn
              + 1,
              sequence: rotate(state.sequence),
              phase: Play,
            )

          False -> state
        }
      })
    }

    Play, PlayCard(player, slot, card) -> {
      Ok(state)
      |> result.then(fn(state) {
        case first(state.sequence) {
          current if player == current -> Ok(state)
          _current -> Error(NotCurrentPlayer)
        }
      })
      |> result.then(fn(state) {
        play_card(state.board, player, slot, card)
        |> result.map(fn(board) { GameState(..state, board: board) })
      })
      |> result.map(fn(state) {
        let total_score = calculate_total_score(state)
        GameState(..state, total_score: total_score)
      })
      |> result.map(fn(state) {
        let hand = get(state.board.hands, player)
        case are_moves_spent(hand), deck_size(state) {
          True, 0 -> GameState(..state, phase: End)

          True, _ -> GameState(..state, phase: Draw)

          False, _ -> state
        }
      })
    }

    _phase, action -> {
      Error(InvalidAction(action))
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

/// Retrieves the current turn
pub fn current_turn(state: GameState) -> Int {
  state.turn
}

/// Retrieves the current phase
pub fn current_phase(state: GameState) -> Phase {
  state.phase
}

/// Retrieves the current player
pub fn current_player(state: GameState) -> Player {
  first(state.sequence)
}

const slots = [Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9]

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

/// Retrieves both player's scores per column 
pub fn score_columns(state: GameState) -> List(#(Score, Score)) {
  state.total_score.columns
}

/// Retrieves the winning score per column
pub fn score_totals(state: GameState) -> List(#(Option(Player), Int)) {
  state.total_score.totals
}

/// Retrieves the winning score 
pub fn score_total(state: GameState) -> #(Option(Player), Int) {
  state.total_score.total
}

// --- Function Helpers --- // 

fn new_board() -> Board {
  Board(
    deck: new_deck(),
    battleline: new_line(
      dict.new()
      |> dict.insert(Player1, [])
      |> dict.insert(Player2, []),
    ),
    hands: dict.new()
    |> dict.insert(Player1, [])
    |> dict.insert(Player2, []),
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
  |> dict.from_list()
}

fn new_total_score() -> TotalScore {
  TotalScore(
    columns: list.map(slots, fn(_) {
      #(Score(0, 0, 0, HighCard), Score(0, 0, 0, HighCard))
    }),
    totals: list.map(slots, fn(_) { figure_player(0) }),
    total: #(None, 0),
  )
}

fn draw_card(board: Board, of player: Player) -> Result(Board, Errors) {
  let hand = get(board.hands, player)
  use #(card, deck) <- try(draw_card_from_deck(board.deck))
  use new_hand <- try(add_card_to_hand(hand, card))
  let hands = dict.insert(board.hands, player, new_hand)
  let board = Board(..board, deck: deck, hands: hands)
  Ok(board)
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

fn formation(column: Column) -> Formation {
  case list.sort(column, by: rank_compare) {
    [card_a, card_b, card_c] -> formation_triplet(card_a, card_b, card_c)
    [card_a, card_b] -> formation_pair(card_a, card_b)
    _other -> HighCard
  }
}

fn rank_compare(card_a: Card, card_b: Card) -> Order {
  let Card(rank: a, ..) = card_a
  let Card(rank: b, ..) = card_b
  int.compare(a, b)
}

fn formation_triplet(card_a: Card, card_b: Card, card_c: Card) -> Formation {
  let Card(suit: sa, rank: ra) = card_a
  let Card(suit: sb, rank: rb) = card_b
  let Card(suit: sc, rank: rc) = card_c

  let is_pair = ra == rb || rb == rc || rc == ra
  let is_triplet = ra == rb && rb == rc
  let is_flush = sa == sb && sb == sc
  let is_straight = { ra + 1 == rb } && { rb + 1 == rc }

  case is_pair, is_triplet, is_flush, is_straight {
    _bool, False, True, True -> StraightFlush
    _bool, True, False, False -> ThreeOfAKind
    _bool, False, False, True -> Straight
    _bool, False, True, False -> Flush
    True, False, False, False -> Pair
    _bool, _bool, _bool, _bool -> HighCard
  }
}

fn formation_pair(card_a: Card, card_b: Card) -> Formation {
  case card_a.rank, card_b.rank {
    ra, rb if ra == rb -> Pair
    _, _ -> HighCard
  }
}

fn play_card(
  board: Board,
  of player: Player,
  at slot: Slot,
  with card: Card,
) -> Result(Board, Errors) {
  let hand = get(board.hands, player)
  let battle = get(board.battleline, slot)
  let column = get(battle, player)

  use #(card, hand) <- try(pick_card(from: hand, where: card))
  use column <- try(available_play(is: column))

  let hands = dict.insert(board.hands, player, hand)

  let column = list.append(column, [card])
  let battle = dict.insert(battle, player, column)
  let battleline = dict.insert(board.battleline, slot, battle)

  let board = Board(..board, hands: hands, battleline: battleline)

  Ok(board)
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

fn are_hands_full(hands: Dict(Player, List(Card))) -> Bool {
  let p1_hand = get(hands, Player1)
  let p2_hand = get(hands, Player2)

  list.length(p1_hand) >= max_hand_size && list.length(p2_hand) >= max_hand_size
}

fn are_moves_spent(hand: List(Card)) -> Bool {
  let moves = max_hand_size - list.length(hand)

  plays_per_turn == moves
}

fn calculate_total_score(state: GameState) -> TotalScore {
  let columns = calculate_columns(state)
  let totals = calculate_totals(columns)
  let total = calculate_total(totals)

  TotalScore(
    columns: columns,
    totals: list.map(totals, figure_player),
    total: figure_player(total),
  )
}

fn calculate_columns(state: GameState) -> List(#(Score, Score)) {
  let columns =
    list.index_map(slots, fn(slot, index) {
      let assert Ok(#(s1, s2)) = list.at(state.total_score.columns, index)

      let battle = get(state.board.battleline, slot)
      let column_p1 = get(battle, Player1)
      let column_p2 = get(battle, Player2)

      #(score(column_p1, s1.bonus_flank), score(column_p2, s2.bonus_flank))
    })

  let flanks = flank_bonuses(columns)

  let columns =
    list.map(slots, fn(slot) {
      let battle = get(state.board.battleline, slot)
      let column_p1 = get(battle, Player1)
      let column_p2 = get(battle, Player2)

      #(score(column_p1, 0), score(column_p2, 0))
    })

  list.zip(columns, flanks)
  |> list.map(fn(scores) {
    let #(#(score_p1, score_p2), bonus) = scores

    case bonus {
      Some(Player1) -> #(Score(..score_p1, bonus_flank: flank_bonus), score_p2)
      Some(Player2) -> #(score_p1, Score(..score_p2, bonus_flank: flank_bonus))
      None -> #(score_p1, score_p2)
    }
  })
}

fn score(column: List(Card), flank: Int) -> Score {
  let formation = formation(column)

  Score(
    score: card_score(column),
    bonus_formation: formation_bonus(formation),
    bonus_flank: flank,
    formation: formation,
  )
}

fn formation_bonus(formation: Formation) -> Int {
  case formation {
    StraightFlush -> straight_flush
    ThreeOfAKind -> three_of_a_kind
    Straight -> straight
    Flush -> flush
    Pair -> pair
    HighCard -> highcard
  }
}

fn flank_bonuses(scores: List(#(Score, Score))) -> List(Option(Player)) {
  scores
  |> list.map(fn(score) {
    let #(score_p1, score_p2) = score
    let score_p1 =
      score_p1.score + score_p1.bonus_formation + score_p1.bonus_flank
    let score_p2 =
      score_p2.score + score_p2.bonus_formation + score_p2.bonus_flank

    score_p1 - score_p2
  })
  |> list.window(3)
  |> list.map(fn(claims) {
    case claims {
      [s1, s2, s3] if s1 > 0 && s2 > 0 && s3 > 0 -> Some(Player1)
      [s1, s2, s3] if s1 < 0 && s2 < 0 && s3 < 0 -> Some(Player2)
      _other -> None
    }
  })
  |> list.prepend(None)
  |> list.append([None])
}

fn calculate_totals(scores: List(#(Score, Score))) -> List(Int) {
  list.map(scores, fn(score) {
    let #(score_p1, score_p2) = score

    let score_p1 =
      score_p1.score + score_p1.bonus_formation + score_p1.bonus_flank
    let score_p2 =
      score_p2.score + score_p2.bonus_formation + score_p2.bonus_flank
    score_p1 - score_p2
  })
}

fn calculate_total(scores: List(Int)) -> Int {
  list.fold(scores, 0, fn(total, score) { total + score })
}

fn figure_player(score: Int) -> #(Option(Player), Int) {
  case score {
    score if score > 0 -> #(Some(Player1), score)
    score if score < 0 -> #(Some(Player2), int.absolute_value(score))
    _score -> #(None, 0)
  }
}

fn get(map: Dict(key, value), key: key) -> value {
  let assert Ok(value) = dict.get(map, key)
  value
}
