import gleam/list
import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/result

pub type GameState {
  GameState(
    phase: Phase,
    battle_line: BattleLine,
    deck: List(Card),
    player_sequence: List(Player),
    hands: Map(Player, List(Card)),
  )
}

pub type Phase {
  GameStart
  InitialDraw
  Draw(Player)
  PlayCard(Player)
  GameEnd
}

pub type Position {
  Position(flag: Option(Player), side: Map(Player, List(Card)))
}

type BattleLine =
  Map(Int, Position)

pub type Player {
  Player(id: String)
  Computer
}

pub type Suit {
  Spade
  Heart
  Diamond
  Club
}

pub type Card {
  Normal(rank: Int, suit: Suit)
}

type Formation {
  Wedge
  Phalanx
  Batallion
  Skirmish
  Host
}

type Victory {
  Breakthrough
  Envelopment
}

pub fn new_game(p1 p1: Player, p2 p2: Player) -> GameState {
  GameState(
    phase: InitialDraw,
    battle_line: new_battle_line(p1, p2),
    deck: new_deck(),
    player_sequence: list.shuffle([p1, p2]),
    hands: new_hands(p1, p2),
  )
}

fn new_battle_line(p1: Player, p2: Player) -> BattleLine {
  let position =
    Position(
      flag: None,
      side: map.new()
      |> map.insert(p1, [])
      |> map.insert(p2, []),
    )

  use map, index <- list.fold(list.range(1, 9), map.new())
  map.insert(map, index, position)
}

fn new_deck() -> List(Card) {
  list.shuffle({
    use rank <- list.flat_map([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    use suit <- list.map([Spade, Heart, Diamond, Club])
    new_card(rank, suit)
  })
}

fn new_hands(p1: Player, p2: Player) -> Map(Player, List(Card)) {
  map.new()
  |> map.insert(p1, [])
  |> map.insert(p2, [])
}

pub fn draw_card(state: GameState, for player: Player) -> #(Card, GameState) {
  let [card, ..deck] = state.deck

  assert Ok(hand) = map.get(state.hands, player)
  let hands = map.insert(state.hands, player, [card, ..hand])

  #(card, GameState(..state, deck: deck, hands: hands))
}

pub fn current_player(state: GameState) -> Player {
  let [player, ..] = state.player_sequence
  player
}

fn play_card(line: BattleLine, card: Card, index: Int) -> BattleLine {
  todo
}

fn new_card(rank: Int, suit: Suit) -> Card {
  Normal(rank: rank, suit: suit)
}

fn available_slots(line: BattleLine, for player: Player) -> List(Int) {
  line
  |> map.filter(fn(_index, position) { position.flag == None })
  |> map.filter(fn(_index, position) {
    assert Ok(cards) = map.get(position.side, player)
    list.length(cards) < 3
  })
  |> map.keys()
}

fn victory(line: BattleLine, for player: Player) -> Bool {
  check_breakthrough(line, for: player) && check_envelopment(line, for: player)
}

fn check_breakthrough(line: BattleLine, for player: Player) -> Bool {
  let chunk =
    list.range(1, 9)
    |> list.map(get_position(line, _))
    |> list.window(3)

  use positions <- list.any(chunk)
  use position <- list.all(positions)
  Some(player) == position.flag
}

fn get_position(line: BattleLine, index: Int) -> Position {
  line
  |> map.get(index)
  |> result.unwrap(Position(flag: None, side: map.new()))
}

fn check_envelopment(line: BattleLine, for player: Player) -> Bool {
  line
  |> map.filter(fn(_index, position) { position.flag == Some(player) })
  |> map.size() >= 5
}
// TODO: Other fields for position:
// * Add hand score 
// * Add hand "weight" or "formation"
// Similar to the flag, this is info that could be computed

// TODO: Create a basic computer player to play against
// * Can do actions and other turns asynchronously
