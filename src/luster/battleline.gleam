import gleam/list
import gleam/map.{type Map}
import gleam/result
import luster/board.{type Board, type Card}

// TODO: Rummy like card play with the discards
// TODO: Play cards 3 by 3
// TODO: Simultaneous play for players
// TODO: Create a basic computer player to play against
// * Can do actions and other turns asynchronously
// TODO: How to protect other players applying actions in place of the other.
// TODO: In extreme scenarios a player could get the whole player's hand by querying the server.

// TODO: Build an introspection API around the general board and functions that are needed

const max_hand_size = 7

pub opaque type GameState {
  GameState(phase: Phase, board: Board, sequence: List(board.Player))
}

type Phase {
  InitialDraw
  ClaimFlag
  PlayCard
  Draw
}

pub type Errors {
  NotCurrentPhase
  NotCurrentPlayer
  Board(board.Errors)
}

// ACTIONS API

pub fn new() -> GameState {
  GameState(
    phase: InitialDraw,
    board: board.new(),
    sequence: list.shuffle([board.Player1, board.Player2]),
  )
}

/// Player draws a card during the Initial Draw phase 
pub fn initial_draw(
  state: GameState,
  of player: board.Player,
) -> Result(GameState, Errors) {
  Ok(state)
  |> result.then(check_phase(_, InitialDraw))
  |> result.then(board_draw_card(_, player))
  |> result.map(next_phase)
}

/// Player claims a flag during the Claim Flag phase
pub fn claim_flag(
  state: GameState,
  of player: board.Player,
  at slot: board.Slot,
) -> Result(GameState, Errors) {
  Ok(state)
  |> result.then(check_phase(_, ClaimFlag))
  |> result.then(check_current_player(_, player))
  |> result.then(board_claim_flag(_, player, slot))
  |> result.map(next_phase)
}

/// Player plays a card during the Play Card phase
pub fn play_card(
  state: GameState,
  of player: board.Player,
  with card: Card,
  at slot: board.Slot,
) -> Result(GameState, Errors) {
  Ok(state)
  |> result.then(check_phase(_, PlayCard))
  |> result.then(check_current_player(_, player))
  |> result.then(board_play_card(_, player, card, slot))
  |> result.map(next_phase)
}

/// Player draws a card during the Draw phase
pub fn replentish_hand(
  state: GameState,
  of player: board.Player,
) -> Result(GameState, Errors) {
  Ok(state)
  |> result.then(check_phase(_, Draw))
  |> result.then(check_current_player(_, player))
  |> result.then(board_draw_card(_, player))
  |> result.map(next_phase)
  |> result.map(next_player)
}

// GAMESTATE INTROSPECTION API

/// Retrieves a player's full hand
pub fn hand(state: GameState, of player: board.Player) -> List(Card) {
  board.hand(state.board, of: player)
}

/// Retrieves the current deck size
pub fn deck_size(state: GameState) -> Int {
  board.deck_size(state.board)
}

// FUNCTION HELPERS

fn board_draw_card(
  state: GameState,
  player: board.Player,
) -> Result(GameState, Errors) {
  case board.draw(state.board, player) {
    Ok(board) -> Ok(GameState(..state, board: board))
    Error(error) -> Error(Board(error))
  }
}

fn board_claim_flag(
  state: GameState,
  player: board.Player,
  slot: board.Slot,
) -> Result(GameState, Errors) {
  case board.claim_flag(state.board, of: player, at: slot) {
    Ok(board) -> Ok(GameState(..state, board: board))
    Error(error) -> Error(Board(error))
  }
}

fn board_play_card(
  state: GameState,
  player: board.Player,
  card: Card,
  slot: board.Slot,
) -> Result(GameState, Errors) {
  case board.play(state.board, with: card, of: player, at: slot) {
    Ok(board) -> Ok(GameState(..state, board: board))
    Error(error) -> Error(Board(error))
  }
}

fn check_phase(state: GameState, phase: Phase) -> Result(GameState, Errors) {
  case state.phase == phase {
    True -> Ok(state)
    False -> Error(NotCurrentPhase)
  }
}

fn check_current_player(
  state: GameState,
  player: board.Player,
) -> Result(GameState, Errors) {
  case first(state.sequence) {
    current if current == player -> Ok(state)
    _other -> Error(NotCurrentPlayer)
  }
}

fn next_phase(state: GameState) -> GameState {
  case state.phase {
    InitialDraw -> {
      let are_hands_complete =
        state.sequence
        |> list.map(fn(board_player) {
          board.hand(state.board, of: board_player)
        })
        |> list.all(fn(hand) { list.length(hand) == max_hand_size })

      case are_hands_complete {
        True -> GameState(..state, phase: ClaimFlag)
        False -> state
      }
    }
    ClaimFlag -> GameState(..state, phase: PlayCard)
    PlayCard -> GameState(..state, phase: Draw)
    Draw -> GameState(..state, phase: ClaimFlag)
  }
}

fn next_player(state: GameState) -> GameState {
  GameState(..state, sequence: rotate(state.sequence))
}

fn first(list: List(x)) -> x {
  let assert [head, ..] = list
  head
}

fn rotate(list: List(x)) -> List(x) {
  let assert [head, ..tail] = list
  list.append(tail, [head])
}
