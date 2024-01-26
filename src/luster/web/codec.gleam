import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/int
import gleam/result.{try}
import luster/game/cardfield.{
  type Card, type Player, type Slot, type Suit, Club, Diamond, Heart, Player1,
  Player2, Slot1, Slot2, Slot3, Slot4, Slot5, Slot6, Slot7, Slot8, Slot9, Spade,
}

pub fn encode_player(player: Player) -> String {
  case player {
    Player1 -> "player-1"
    Player2 -> "player-2"
  }
}

pub fn encode_slot(slot: Slot) -> String {
  case slot {
    Slot1 -> "1"
    Slot2 -> "2"
    Slot3 -> "3"
    Slot4 -> "4"
    Slot5 -> "5"
    Slot6 -> "6"
    Slot7 -> "7"
    Slot8 -> "8"
    Slot9 -> "9"
  }
}

pub fn encode_rank(rank: Int) -> String {
  int.to_string(rank)
}

pub fn encode_suit(suit: Suit) -> String {
  case suit {
    Spade -> "♠"
    Heart -> "♥"
    Diamond -> "♦"
    Club -> "♣"
  }
}

pub fn decoder_player(data: Dynamic) -> Result(Player, List(DecodeError)) {
  dynamic.field("player", of: decode_player)(data)
}

pub fn decoder_slot(data: Dynamic) -> Result(Slot, List(DecodeError)) {
  dynamic.field("slot", of: decode_slot)(data)
}

pub fn decoder_card(data: Dynamic) -> Result(Card, List(DecodeError)) {
  dynamic.decode2(
    cardfield.Card,
    dynamic.field("rank", of: decode_rank),
    dynamic.field("suit", of: decode_suit),
  )(data)
}

fn decode_player(data: Dynamic) -> Result(Player, List(DecodeError)) {
  use string <- try(dynamic.string(data))
  use player <- try(to_player(string))
  Ok(player)
}

fn decode_slot(data: Dynamic) -> Result(Slot, List(DecodeError)) {
  use string <- try(dynamic.string(data))
  use slot <- try(to_slot(string))
  Ok(slot)
}

fn decode_suit(data: Dynamic) -> Result(Suit, List(DecodeError)) {
  use string <- try(dynamic.string(data))
  use suit <- try(to_suit(string))
  Ok(suit)
}

fn decode_rank(data: Dynamic) -> Result(Int, List(DecodeError)) {
  use string <- try(dynamic.string(data))
  use rank <- try(to_rank(string))
  Ok(rank)
}

fn to_player(string: String) -> Result(Player, List(DecodeError)) {
  case string {
    "player-1" -> Ok(Player1)
    "player-2" -> Ok(Player2)
    string ->
      Error([dynamic.DecodeError(expected: "player", found: string, path: [])])
  }
}

fn to_slot(string: String) -> Result(Slot, List(DecodeError)) {
  case string {
    "1" -> Ok(Slot1)
    "2" -> Ok(Slot2)
    "3" -> Ok(Slot3)
    "4" -> Ok(Slot4)
    "5" -> Ok(Slot5)
    "6" -> Ok(Slot6)
    "7" -> Ok(Slot7)
    "8" -> Ok(Slot8)
    "9" -> Ok(Slot9)
    x -> Error([dynamic.DecodeError(expected: "1..9", found: x, path: [])])
  }
}

fn to_suit(string: String) -> Result(Suit, List(DecodeError)) {
  case string {
    "♠" -> Ok(Spade)
    "♥" -> Ok(Heart)
    "♦" -> Ok(Diamond)
    "♣" -> Ok(Club)
    string ->
      Error([
        dynamic.DecodeError(expected: "♠♥♦♣", found: string, path: []),
      ])
  }
}

fn to_rank(string: String) -> Result(Int, List(DecodeError)) {
  case int.parse(string) {
    Ok(value) -> Ok(value)
    Error(Nil) ->
      Error([dynamic.DecodeError(expected: "Number", found: string, path: [])])
  }
}
