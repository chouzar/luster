import gleam/string
import gleam/list
import gleam/result
import gleam/bbmustache.{CompileError} as mustache
import luster/util

pub type Template {
  // TODO: Maybe add a "static" constructor
  Layout(path: String, contents: List(#(String, Template)))
  Many(contents: List(Template))
  Raw(contents: String)
}

pub fn render(template: Template) -> Result(String, String) {
  case template {
    Layout(path: path, contents: contents) ->
      Layout(path: path, contents: contents)
      |> render_layout()

    Many(contents: contents) ->
      Many(contents: contents)
      |> render_many()

    Raw(contents: contents) ->
      Raw(contents: contents)
      |> render_raw()
  }
}

fn render_layout(template: Template) -> Result(String, String) {
  let assert Layout(path: path, contents: contents) = template

  let base_path = util.root_path()

  let full_path =
    [base_path, path]
    |> string.join(with: "/")

  case mustache.compile_file(full_path) {
    Ok(compiled) ->
      contents
      |> list.map(render_embed)
      |> result.all()
      |> result.map(mustache.render(compiled, _))

    Error(error) ->
      error
      |> report(base_path, path)
  }
}

fn render_embed(
  embed: #(String, Template),
) -> Result(#(String, mustache.Argument), String) {
  let #(token, content) = embed

  content
  |> render()
  |> result.map(mustache.string)
  |> result.map(fn(content) { #(token, content) })
}

fn render_many(template: Template) -> Result(String, String) {
  let assert Many(contents: contents) = template

  contents
  |> list.map(render)
  |> result.all()
  |> result.map(string.join(_, "\n"))
}

fn render_raw(template: Template) -> Result(String, String) {
  let assert Raw(contents: contents) = template

  Ok(contents)
}

fn report(
  error: CompileError,
  base_path: String,
  path: String,
) -> Result(String, String) {
  util.report([
    "Error: " <> string.inspect(Error(error)),
    "Base: " <> base_path,
    "Path: " <> path,
  ])

  Error("Unable to render page")
}
