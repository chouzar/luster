import gleam/string_builder.{StringBuilder}
import luster/web/template

pub type Action {
  Append
  Prepend
  Replace
  Update
  Remove
  Before
  After
}

pub opaque type Stream {
  Stream(builder: StringBuilder)
}

pub fn new() -> Stream {
  string_builder.new()
  |> Stream()
}

pub fn add(
  stream: Stream,
  do action: Action,
  at target: String,
  with content: String,
) -> Stream {
  let content = wrap(action, target, content)
  stream.builder
  |> string_builder.append(content)
  |> Stream()
}

pub fn render(stream: Stream) -> String {
  stream.builder
  |> string_builder.to_string()
}

fn wrap(action: Action, target: String, content: String) -> String {
  let action = case action {
    Append -> "append"
    Prepend -> "prepend"
    Replace -> "replace"
    Update -> "update"
    Remove -> "remove"
    Before -> "before"
    After -> "after"
  }

  template.new("src/luster/web/component")
  |> template.from("turbo_stream.html")
  |> template.args(replace: "action", with: action)
  |> template.args(replace: "target", with: target)
  |> template.args(replace: "content", with: content)
  |> template.render()
}
