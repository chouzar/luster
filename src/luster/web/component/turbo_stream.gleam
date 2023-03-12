import gleam/string_builder.{StringBuilder}
import gleam/bbmustache.{CompileError}
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

pub fn render(
  action: Action,
  target: String,
  content: String,
) -> Result(String, CompileError) {
  let action = case action {
    Append -> "append"
    Prepend -> "prepend"
    Replace -> "replace"
    Update -> "update"
    Remove -> "remove"
    Before -> "before"
    After -> "after"
  }

  template.new("src/luster/web/component/turbo_stream.html")
  |> template.args(replace: "action", with: action)
  |> template.args(replace: "target", with: target)
  |> template.args(replace: "content", with: content)
  |> template.render()
}
