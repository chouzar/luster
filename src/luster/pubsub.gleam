import chip
import gleam/erlang/process
import gleam/list
import gleam/otp/actor

pub type PubSub(channel, message) =
  process.Subject(chip.Message(channel, message))

pub fn start() -> Result(PubSub(channel, message), actor.StartError) {
  chip.start()
}

pub fn register(
  pubsub: PubSub(channel, message),
  channel: channel,
  subject: process.Subject(message),
) -> Nil {
  let _ = chip.register_as(pubsub, channel, fn() { Ok(subject) })
  Nil
}

pub fn broadcast(
  pubsub: PubSub(channel, message),
  channel: channel,
  message: message,
) -> Nil {
  chip.lookup(pubsub, channel)
  |> list.map(fn(subject) { process.send(subject, message) })

  Nil
}
