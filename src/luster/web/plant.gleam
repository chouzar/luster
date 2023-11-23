import gleam/string
import gleam/list
import gleam/uri.{type Uri}
import gleam/result
import gleam/bbmustache as mustache
import luster/util

// TODO: For the time being every error is a string
// * Errors could be user defined via a callback.
//   * Must rescue previous error logic
//   * Must identify not to repeat error logic. 
// * Currently there's only 1 "report" function to handle errors
//   * It should probably be specific to the problem.
// * The function would be wrapped up to implement different callbacks. 
type Source {
  File(String)
  Text(String)
}

pub opaque type Template {
  Layout(source: Source, contents: List(#(String, Template)))
  Many(contents: List(Template))
}

// TODO: A type for carrying metadata with builder pattern.
// * Current template traversal
// * Current source file
// * List of errors
// or custom errors for each case
pub fn lay(
  from source: String,
  with contents: List(#(String, Template)),
) -> Template {
  Layout(File(source), contents)
}

pub fn many(contents: List(Template)) -> Template {
  Many(contents)
}

pub fn static(from source: String) -> Template {
  Layout(File(source), [])
}

pub fn raw(content: String) -> Template {
  Layout(Text(content), [])
}

// TODO: Should probably return `Result(String, List(error))`
// TODO: Have a traversal function for managing internals (and better naming)
pub fn render(template: Template) -> Result(String, String) {
  case template {
    Layout(source: source, contents: contents) ->
      Ok(source)
      |> result.then(read_source)
      |> result.then(compile_layout)
      |> result.then(apply_contents(_, contents))
      |> result.map_error(report)

    Many(contents: contents) ->
      contents
      |> list.map(render)
      |> result.all()
      |> result.map(string.join(_, "\n"))
  }
}

fn read_source(source: Source) -> Result(String, String) {
  case source {
    File(path) ->
      Ok(path)
      |> result.then(uri.parse)
      |> result.then(read_file)
      |> result.map_error(report)

    Text(raw) -> Ok(raw)
  }
}

// Callback to read a file path
fn read_file(uri: Uri) -> Result(String, Nil) {
  let read = fn(x) { util.read_file(x) }

  [util.root_path(), uri.path]
  |> string.join(with: "/")
  |> read()
}

// Callback to compile layout
fn compile_layout(layout: String) -> Result(mustache.Template, String) {
  let compile = fn(x) { mustache.compile(x) }

  Ok(layout)
  |> result.then(compile)
  |> result.map_error(report)
}

// Callback to apply embedded contents
fn apply_contents(
  compiled: mustache.Template,
  contents: List(#(String, Template)),
) -> Result(String, String) {
  let mustache_render = fn(contents) { mustache.render(compiled, contents) }

  contents
  |> list.map(render_embed)
  |> result.all()
  |> result.map(mustache_render)
}

fn render_embed(
  embed: #(String, Template),
) -> Result(#(String, mustache.Argument), String) {
  let #(token, content) = embed

  content
  |> render()
  |> result.map(mustache.string)
  |> result.map(fn(content) { #(token, content) })
  |> result.map_error(report)
}

fn report(error: error) -> String {
  util.report(["Error: " <> string.inspect(Error(error))])

  "Unable to render page"
}
