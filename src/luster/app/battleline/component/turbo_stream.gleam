import luster/server/template

pub type Action {
  Append
  Prepend
  Replace
  Remove
  Before
  After
}

pub fn render(action: Action, target: String, content: String) -> String {
  let action = case action {
    Append -> "append"
    Prepend -> "prepend"
    Replace -> "replace"
    Remove -> "remove"
    Before -> "before"
    After -> "after"
  }

  template.new(["src", "luster", "app", "battleline", "component"])
  |> template.from(["turbo_stream.html"])
  |> template.args(replace: "action", with: action)
  |> template.args(replace: "target", with: target)
  |> template.args(replace: "content", with: content)
  |> template.render()
}
