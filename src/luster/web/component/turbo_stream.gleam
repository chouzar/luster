import luster/web/plant

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
  with content: plant.Template,
) -> plant.Template {
  let action = case action {
    Append -> "append"
    Prepend -> "prepend"
    Replace -> "replace"
    Update -> "update"
    Remove -> "remove"
    Before -> "before"
    After -> "after"
  }

  plant.lay(
    from: "src/luster/web/component/turbo_stream.html",
    with: [
      #("action", plant.raw(action)),
      #("target", plant.raw(target)),
      #("content", content),
    ],
  )
}
