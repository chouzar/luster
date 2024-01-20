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

const max_hand_size = 8

const plays_per_turn = 4

const slots = [Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9]

const ranks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

const suits = [Spade, Heart, Diamond, Club]

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
    formation: Formation,
    in_flank: Bool,
    card_score: Int,
    formation_bonus: Int,
    flank_bonus: Int,
  )
}

pub type Errors {
  InvalidAction(Action)
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
    sequence: list.shuffle([Player1, Player2]),
    total_score: new_total_score(),
  )
}

pub type Action {
  DrawCard(player: Player)
  PlayCard(player: Player, slot: Slot, card: Card)
}

/// Modifies the game state by applying an action.
pub fn next(state: GameState, action: Action) -> Result(GameState, Errors) {
  let check_current_player = fn(state: GameState, player) {
    let current = first(state.sequence)

    case state.turn, player {
      0, _player -> Ok(state)
      _, player if player == current -> Ok(state)
      _, _ -> Error(NotCurrentPlayer)
    }
  }

  case state.phase, action {
    Draw, DrawCard(player) -> {
      Ok(state)
      |> result.then(check_current_player(_, player))
      |> result.then(fn(state) {
        draw_card(state.board, player)
        |> result.map(fn(board) { GameState(..state, board: board) })
      })
      |> result.map(fn(state) {
        case are_hands_full(state.board.hands) {
          True ->
            GameState(
              ..state,
              turn: state.turn + 1,
              sequence: rotate(state.sequence),
              phase: Play,
            )

          False -> state
        }
      })
    }

    Play, PlayCard(player, slot, card) -> {
      Ok(state)
      |> result.then(check_current_player(_, player))
      |> result.then(fn(state) {
        play_card(state.board, player, slot, card)
        |> result.map(fn(board) { GameState(..state, board: board) })
      })
      |> result.map(fn(state) {
        let total_score = calculate_total_score(state.board.battleline)
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

fn new_total_score() -> TotalScore {
  TotalScore(
    columns: list.map(slots, fn(_) { #(new_score(), new_score()) }),
    totals: list.map(slots, fn(_) { figure_player(0) }),
    total: #(None, 0),
  )
}

fn new_score() -> Score {
  Score(HighCard, False, 0, 0, 0)
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

fn draw_card(board: Board, of player: Player) -> Result(Board, Errors) {
  let hand = get(board.hands, player)
  use #(card, deck) <- try(draw_card_from_deck(board.deck))
  use new_hand <- try(add_card_to_hand(hand, card))
  let hands = map.insert(board.hands, player, new_hand)
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

fn scoring(column: Column) -> Int {
  case formation(column) {
    StraightFlush -> 11
    ThreeOfAKind -> 7
    Straight -> 5
    Flush -> 3
    Pair -> 1
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

  let pair = ra == rb || rb == rc || rc == ra
  let triplet = ra == rb && rb == rc
  let straight = sa == sb && sb == sc
  let flush = { ra + 1 == rb } && { rb + 1 == rc }

  case pair, triplet, straight, flush {
    _bool, False, True, True -> StraightFlush
    _bool, True, False, False -> ThreeOfAKind
    _bool, False, True, False -> Straight
    _bool, False, False, True -> Flush
    True, False, False, False -> Pair
    False, False, False, False -> HighCard
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

  let hands = map.insert(board.hands, player, hand)

  let column = list.append(column, [card])
  let battle = map.insert(battle, player, column)
  let battleline = map.insert(board.battleline, slot, battle)

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

fn are_hands_full(hands: Map(Player, List(Card))) -> Bool {
  let p1_hand = get(hands, Player1)
  let p2_hand = get(hands, Player2)

  list.length(p1_hand) >= max_hand_size && list.length(p2_hand) >= max_hand_size
}

fn are_moves_spent(hand: List(Card)) -> Bool {
  let moves = max_hand_size - list.length(hand)

  plays_per_turn == moves
}

fn calculate_total_score(battleline: Line(Battle)) -> TotalScore {
  let columns = calculate_columns(battleline)
  let totals = calculate_totals(columns)
  let total = calculate_total(totals)

  TotalScore(
    columns: columns,
    totals: list.map(totals, figure_player),
    total: figure_player(total),
  )
}

fn calculate_columns(battleline: Line(Battle)) -> List(#(Score, Score)) {
  let score_p1 = new_score()
  let score_p2 = new_score()

  slots
  |> list.map(fn(slot) {
    let battle = get(battleline, slot)
    let column_p1 = get(battle, Player1)
    let column_p2 = get(battle, Player2)

    let card_p1 = card_score(column_p1)
    let bonus_p1 = scoring(column_p1)
    let card_p2 = card_score(column_p2)
    let bonus_p2 = scoring(column_p2)

    #(
      Score(
        ..score_p1,
        card_score: card_p1,
        formation_bonus: bonus_p1,
        flank_bonus: 0,
      ),
      Score(
        ..score_p2,
        card_score: card_p2,
        formation_bonus: bonus_p2,
        flank_bonus: 0,
      ),
    )
  })
}

fn calculate_totals(scores: List(#(Score, Score))) -> List(Int) {
  list.map(
    scores,
    fn(score) {
      let #(score_p1, score_p2) = score

      let score_p1 = score_p1.card_score + score_p1.formation_bonus
      let score_p2 = score_p2.card_score + score_p2.formation_bonus

      score_p1 - score_p2
    },
  )
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
