import gleam/int
import gleam/list
import gleam/map.{type Map}
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order, Eq, Gt, Lt}
import gleam/result.{try}

// IDEA: Add rummy like card play with discards
// IDEA: Create basic computer players 
// IDEA: Remove 3 card limit for colums, have a diff trigger for countdown
// IDEA: Counter mechanic, being able to "steal" a card and place elsewhere
// IDEA: Add sprites with animations instead of ranks

pub opaque type GameState {
  GameState(phase: Phase, board: Board, sequence: List(Player))
}

pub type Phase {
  FillHandPhase
  ClaimFlagPhase
  PlayCardPhase
  ReplentishPhase
  End
}

pub opaque type Board {
  Board(
    deck: List(Card),
    hands: Map(Player, List(Card)),
    battleline: Line(Battle),
    flags: Line(Flag),
  )
}

pub type Player {
  Player1
  Player2
}

type Line(piece) =
  Map(Slot, piece)

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

type Flag =
  Option(Player)

type Column =
  List(Card)

type Formation {
  ThreeSuitsInSequence
  ThreeRanks
  ThreeInSequence
  ThreeSuits
  HighCard
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

const max_hand_size = 7

const slots = [Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9]

const ranks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

const suits = [Spade, Heart, Diamond, Club]

// --- GameState API --- //

/// Initializes a new gamestate.
pub fn new() -> GameState {
  GameState(
    phase: FillHandPhase,
    board: board_new(),
    sequence: list.shuffle([Player1, Player2]),
  )
}

pub type Action {
  DrawCard(player: Player)
  ClaimFlag(player: Player, slot: Slot)
  PlayCard(player: Player, slot: Slot, card: Card)
}

/// Modifies the game state by applying an action.
pub fn next(state: GameState, action: Action) -> Result(GameState, Errors) {
  let current = first(state.sequence)

  case state.phase, action {
    FillHandPhase, DrawCard(player) -> {
      state
      |> draw_card(player)
      |> result.map(next_phase)
    }

    ClaimFlagPhase, ClaimFlag(player, slot) if player == current -> {
      state
      |> claim_flag(player, slot)
      |> result.map(next_phase)
      |> result.map(next_player)
    }

    PlayCardPhase, PlayCard(player, slot, card) if player == current -> {
      state
      |> play_card(player, slot, card)
      |> result.map(next_phase)
      |> result.map(next_player)
    }

    ReplentishPhase, DrawCard(player) if player == current -> {
      state
      |> draw_card(player)
      |> result.map(next_phase)
      |> result.map(next_player)
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
pub fn columns(board: Board, of player: Player) -> List(Column) {
  let battleline = board.battleline

  slots
  |> list.map(fn(slot) { get(battleline, slot) })
  |> list.map(fn(battle) { get(battle, player) })
}

/// Retrieves slots available for claiming a flag.
pub fn available_claims(state: GameState, of player: Player) -> List(Slot) {
  let GameState(board: board, ..) = state

  slots
  |> list.filter(fn(slot) {
    board.battleline
    |> get(slot)
    |> current_claim() == Some(player)
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

// 
// /// Goes through a player's columns and checks for a breakthrough win.
// fn is_breakthrough(board: Board, of player: Player) -> Bool {
//   let flags = board.flags
// 
//   slots
//   |> list.map(fn(slot) { get(flags, slot) })
//   |> list.window(3)
//   |> list.any(fn(claims) { list.all(claims, fn(flag) { flag == Some(player) }) })
// }
// 
// /// Goes through a player's columns and checks for an envelopment win.
// fn is_envelopment(board: Board, of player: Player) -> Bool {
//   board.flags
//   |> map.filter(fn(_slot, flag) { flag == Some(player) })
//   |> map.size() >= 5
// }

// --- Function Helpers --- // 

fn board_new() -> Board {
  Board(
    deck: new_deck(),
    battleline: new_line(
      map.new()
      |> map.insert(Player1, [])
      |> map.insert(Player2, []),
    ),
    flags: new_line(None),
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

fn claim_flag(
  state: GameState,
  of player: Player,
  at slot: Slot,
) -> Result(GameState, Errors) {
  let GameState(board: board, ..) = state
  let battle = get(board.battleline, slot)

  case current_claim(battle) {
    claim if claim == Some(player) -> {
      let flags = map.insert(board.flags, slot, claim)
      let board = Board(..board, flags: flags)
      let state = GameState(..state, board: board)
      Ok(state)
    }
    _other -> Error(NotClaimableSlot)
  }
}

fn current_claim(battle: Battle) -> Option(Player) {
  let p1_column = get(battle, Player1)
  let p2_column = get(battle, Player1)

  case formation(p1_column), formation(p2_column) {
    Some(p1_formation), Some(p2_formation) ->
      case formation_compare(p1_formation, p2_formation) {
        Eq -> None
        Gt -> Some(Player1)
        Lt -> Some(Player2)
      }
    _, _ -> None
  }
}

fn formation(column: Column) -> Option(Formation) {
  case list.sort(column, by: rank_compare) {
    [card_a, card_b, card_c] -> Some(formation_type(card_a, card_b, card_c))
    _other -> None
  }
}

fn rank_compare(card_a: Card, card_b: Card) -> Order {
  let Card(rank: a, ..) = card_a
  let Card(rank: b, ..) = card_b
  int.compare(a, b)
}

fn formation_compare(formation_a: Formation, formation_b: Formation) -> Order {
  case formation_a, formation_b {
    formation_a, formation_b if formation_a == formation_b -> Eq
    ThreeSuitsInSequence, _formation -> Gt
    _formation, ThreeSuitsInSequence -> Lt
    ThreeRanks, _formation -> Gt
    _formation, ThreeRanks -> Lt
    ThreeInSequence, _formation -> Gt
    _formation, ThreeInSequence -> Lt
    ThreeSuits, _formation -> Gt
    _formation, ThreeSuits -> Lt
    HighCard, _formation -> Gt
    _formation, HighCard -> Lt
  }
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

  let column = [card, ..column]
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

fn next_player(state: GameState) -> GameState {
  GameState(..state, sequence: rotate(state.sequence))
}

fn rotate(list: List(x)) -> List(x) {
  let assert [head, ..tail] = list
  list.append(tail, [head])
}

fn first(list: List(x)) -> x {
  let assert [head, ..] = list
  head
}

fn next_phase(state: GameState) -> GameState {
  case state.phase {
    FillHandPhase ->
      case are_hands_full(state.board.hands) {
        True -> GameState(..state, phase: PlayCardPhase)
        False -> state
      }

    ClaimFlagPhase -> GameState(..state, phase: PlayCardPhase)
    PlayCardPhase -> GameState(..state, phase: ReplentishPhase)
    ReplentishPhase -> GameState(..state, phase: ClaimFlagPhase)
    End -> state
  }
}

fn are_hands_full(hands: Map(Player, List(Card))) -> Bool {
  let p1_hand = get(hands, Player1)
  let p2_hand = get(hands, Player2)

  list.length(p1_hand) >= max_hand_size && list.length(p2_hand) >= max_hand_size
}

fn get(map: Map(key, value), key: key) -> value {
  let assert Ok(value) = map.get(map, key)
  value
}
