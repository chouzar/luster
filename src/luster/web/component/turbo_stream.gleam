import luster/web/plant.{Layout, Raw, Template}

pub type Action {
  Append
  Prepend
  Replace
  Update
  Remove
  Before
  After
}

pub fn new(
  do action: Action,
  at target: String,
  with content: Template,
) -> Template {
  let action = case action {
    Append -> "append"
    Prepend -> "prepend"
    Replace -> "replace"
    Update -> "update"
    Remove -> "remove"
    Before -> "before"
    After -> "after"
  }

  Layout(
    path: "src/luster/web/component/turbo_stream.html",
    contents: [
      #("action", Raw(action)),
      #("target", Raw(target)),
      #("content", content),
    ],
  )
}
