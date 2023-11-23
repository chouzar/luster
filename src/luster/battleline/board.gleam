import gleam/int
import gleam/list
import gleam/map.{type Map}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/order.{type Order, Eq, Gt, Lt}
import luster/battleline/pieces.{type Card, Club, Diamond, Heart, Normal, Spade}

pub type Player {
  Player1
  Player2
}

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

const slots = [Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9]

type Formation {
  ThreeSuitsInSequence
  ThreeRanks
  ThreeInSequence
  ThreeSuits
  HighCard
}

type Pile =
  List(Card)

type Line(piece) =
  Map(Slot, piece)

type Column =
  List(Card)

type Battle =
  Map(Player, Column)

type Flag =
  Option(Player)

type Hand =
  List(Card)

pub opaque type Board {
  Board(
    deck: Pile,
    battleline: Line(Battle),
    hands: Map(Player, Hand),
    flags: Line(Flag),
  )
}

pub type Errors {
  EmptyDeck
  MaxHandReached
  NoCardInHand
  NotPlayableSlot
  NotClaimableSlot
}

// MANIPULATE BOARD API

/// Starts a completely new Board.
pub fn new() -> Board {
  Board(
    deck: new_deck(),
    battleline: new_line(new_battle()),
    flags: new_line(None),
    hands: new_hands(),
  )
}

/// Claims a flag to the player winning the battle.
pub fn claim_flag(
  board: Board,
  of player: Player,
  at slot: Slot,
) -> Result(Board, Errors) {
  let battle = get(board.battleline, slot)

  // TODO: move to a diff function
  case current_claim(battle) {
    claim if claim == Some(player) -> {
      let flags = map.insert(board.flags, slot, claim)
      Ok(Board(..board, flags: flags))
    }
    _other -> Error(NotClaimableSlot)
  }
}

/// Plays a card from a player's hand into an available slot.
pub fn play(
  board: Board,
  of player: Player,
  with card: Card,
  at slot: Slot,
) -> Result(Board, Errors) {
  let hand = get(board.hands, player)
  let battle = get(board.battleline, slot)
  let column = get(battle, player)

  use #(card, hand) <- result.then(pick_card(from: hand, where: card))
  use column <- result.then(available_play(is: column))

  let hands = map.insert(board.hands, player, hand)

  let column = [card, ..column]
  let battle = map.insert(battle, player, column)
  let battleline = map.insert(board.battleline, slot, battle)

  Ok(Board(..board, hands: hands, battleline: battleline))
}

/// Draws a single Card from the Deck to the player's hand.
pub fn draw(board: Board, for player: Player) -> Result(Board, Errors) {
  use #(card, deck) <- result.then(draw_card(board.deck))

  let hand = get(board.hands, player)
  let hand = list.append(hand, [card])

  use hand <- result.then(available_draw(hand))
  let hands = map.insert(board.hands, player, hand)

  Ok(Board(..board, hands: hands, deck: deck))
}

// BOARD INTROSPECTION API

/// Retrieves the current deck size from the Board.
pub fn deck_size(board: Board) -> Int {
  list.length(board.deck)
}

/// Retrieves a player's full hand
pub fn hand(board: Board, of player: Player) -> Hand {
  get(board.hands, player)
}

/// Retrieves battle columns from a player in the right order.
fn columns(board: Board, of player: Player) -> List(Column) {
  let battleline = board.battleline

  slots
  |> list.map(fn(slot) { get(battleline, slot) })
  |> list.map(fn(battle) { get(battle, player) })
}

/// Retrieves a list of slots available for claiming a flag.
fn available_claims(board: Board, of player: Player) -> List(Slot) {
  slots
  |> list.filter(fn(slot) {
    board.battleline
    |> get(slot)
    |> current_claim() == Some(player)
  })
}

/// Retrieves a list of slots available for playing a card.
fn available_plays(board: Board, of player: Player) -> List(Slot) {
  let battleline = board.battleline

  use slot <- list.filter(slots)
  let battle = get(battleline, slot)
  let column = get(battle, player)

  column
  |> available_play()
  |> result.is_ok()
}

/// Goes through a player's columns and checks for a breakthrough win.
fn is_breakthrough(board: Board, of player: Player) -> Bool {
  let flags = board.flags

  slots
  |> list.map(fn(slot) { get(flags, slot) })
  |> list.window(3)
  |> list.any(fn(claims) { list.all(claims, fn(flag) { flag == Some(player) }) })
}

/// Goes through a player's columns and checks for an envelopment win.
fn is_envelopment(board: Board, of player: Player) -> Bool {
  board.flags
  |> map.filter(fn(_slot, flag) { flag == Some(player) })
  |> map.size() >= 5
}

// FUNCTION HELPERS

fn new_deck() -> Pile {
  list.shuffle({
    use rank <- list.flat_map([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    use suit <- list.map([Spade, Heart, Diamond, Club])
    Normal(rank: rank, suit: suit)
  })
}

fn new_line(of piece: piece) -> Line(piece) {
  slots
  |> list.map(fn(slot) { #(slot, piece) })
  |> map.from_list()
}

fn new_battle() -> Battle {
  map.new()
  |> map.insert(Player1, [])
  |> map.insert(Player2, [])
}

fn new_hands() -> Map(Player, Hand) {
  map.new()
  |> map.insert(Player1, [])
  |> map.insert(Player2, [])
}

fn pick_card(from hand: Hand, where card: Card) -> Result(#(Card, Hand), Errors) {
  hand
  |> list.pop(fn(c) { c == card })
  |> result.replace_error(NoCardInHand)
}

fn draw_card(deck: Pile) -> Result(#(Card, Pile), Errors) {
  deck
  |> list.pop(fn(_) { True })
  |> result.replace_error(EmptyDeck)
}

fn available_draw(hand: Hand) -> Result(Hand, Errors) {
  case list.length(hand) > 7 {
    True -> Error(MaxHandReached)
    False -> Ok(hand)
  }
}

fn available_play(is column: Column) -> Result(Column, Errors) {
  case column {
    [_, _, _] -> Error(NotPlayableSlot)
    column -> Ok(column)
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
  let Normal(rank: a, ..) = card_a
  let Normal(rank: b, ..) = card_b
  int.compare(a, b)
}

fn formation_type(card_a: Card, card_b: Card, card_c: Card) -> Formation {
  let Normal(suit: sa, rank: ra) = card_a
  let Normal(suit: sb, rank: rb) = card_b
  let Normal(suit: sc, rank: rc) = card_c

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

fn get(map: Map(key, value), key: key) -> value {
  let assert Ok(value) = map.get(map, key)
  value
}
