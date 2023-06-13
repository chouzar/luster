import gleam/int
import gleam/list
import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/result

pub type Card {
  Normal(rank: Int, suit: Suit)
}

pub type Suit {
  Spade
  Heart
  Diamond
  Club
}

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
    flags: Line(Option(Player)),
    hands: Map(Player, Hand),
  )
}

pub type Errors {
  EmptyDeck
  NoCardInHand
}

pub fn new() -> Board {
  Board(
    deck: new_deck(),
    battleline: new_line(new_battle()),
    flags: new_line(None),
    hands: new_hands(),
  )
}

fn new_deck() -> Pile {
  list.shuffle({
    use rank <- list.flat_map([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    use suit <- list.map([Spade, Heart, Diamond, Club])
    Normal(rank: rank, suit: suit)
  })
}

fn new_line(of piece: piece) -> Line(piece) {
  [Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9]
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

// TODO: Introspection helpers to know:
// * available moves
// * check formation wins

// TODO: Eventually the state should be observable so we can send simple
// datastructures to the front end

pub fn draw(board: Board, player: Player) -> Result(Board, Errors) {
  let Board(deck: deck, hands: hands, ..) = board

  use #(card, deck) <- result.map(take_from_deck(deck))
  let assert Ok(hand) = map.get(hands, player)

  let hand = list.append(hand, [card])
  let hands = map.insert(hands, player, hand)

  Board(..board, hands: hands, deck: deck)
}

// TODO: Validate max of 3 cards per slot
pub fn play(
  board: Board,
  from player: Player,
  with card: Card,
  at slot: Slot,
) -> Result(Board, Errors) {
  let Board(hands: hands, battleline: battleline, ..) = board

  let assert Ok(hand) = map.get(hands, player)
  use #(card, hand) <- result.map(take_from_hand(hand, where: card))
  let assert Ok(battle) = map.get(battleline, slot)
  let assert Ok(column) = map.get(battle, player)

  let battle = map.insert(battle, player, [card, ..column])
  let battleline = map.insert(battleline, slot, battle)
  let hands = map.insert(hands, player, hand)

  Board(..board, hands: hands, battleline: battleline)
}

pub fn reorder_hand(board: Board, from player: Player) -> Board {
  todo
}

fn take_from_deck(deck: Pile) -> Result(#(Card, Pile), Errors) {
  case deck {
    [card, ..deck] -> Ok(#(card, deck))
    [] -> Error(EmptyDeck)
  }
}

fn take_from_hand(hand: Hand, where card: Card) -> Result(#(Card, Hand), Errors) {
  hand
  |> list.pop(fn(c) { c == card })
  |> result.replace_error(NoCardInHand)
}
