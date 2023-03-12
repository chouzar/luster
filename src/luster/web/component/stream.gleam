import gleam/result
import gleam/list
import gleam/string
import gleam/string_builder.{StringBuilder}
import gleam/bbmustache.{CompileError}
import luster/web/template
import luster/web/component/turbo_stream.{Action}

pub opaque type Stream {
  Stream(fragments: List(Fragment))
}

type Fragment {
  Fragment(action: Action, target: String, content: String)
}

pub fn new() -> Stream {
  Stream([])
}

pub fn add(
  stream: Stream,
  do action: Action,
  at target: String,
  with content: String,
) -> Stream {
  Stream([Fragment(action, target, content), ..stream.fragments])
}

pub fn render(stream: Stream) -> Result(String, CompileError) {
  // TODO: find a way to do strinbuilder
  stream.fragments
  |> list.map(fn(fragment) {
    turbo_stream.render(fragment.action, fragment.target, fragment.content)
  })
  |> result.all()
  |> result.map(string.join(_, "\n"))
}
