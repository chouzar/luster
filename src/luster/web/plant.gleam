import gleam/string
import gleam/list
import gleam/result
import gleam/bbmustache as mustache
import luster/util

// TODO: Choose a good name for this.
// * Lay, Plant

// TODO: We can futher de-couple bbmustache from the template engine
// * Have it only compose string layouts
// * Render function could have callbacks to use an engine
// * Render function could generate a new function to use as an engine
//   * render(from: File("x"), read_as, build_as), Providing a type
//   * render(from: Text("x"), read_as, build_as), Providing a type
//   * render(from: "xyz", fn(x) { x }, build_as), Providing a function
//   * render(from: "xyz", None, Some(fn(x) { x })), These are implicit
//   * render(from: "xyz", Some(fn(x) { x }), None), These are implicit

pub type Template {
  Layout(path: String, contents: List(#(String, Template)))
  Static(path: String)
  Many(contents: List(Template))
  Raw(contents: String)
}

pub fn render(template: Template) -> Result(String, String) {
  case template {
    Layout(path: path, contents: contents) ->
      Layout(path: path, contents: contents)
      |> render_layout()

    Static(path: path) ->
      Static(path: path)
      |> render_static()

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

    Error(error) -> {
      util.report([
        "Error: " <> string.inspect(Error(error)),
        "Base: " <> base_path,
        "Path: " <> path,
      ])

      Error("Unable to render page")
    }
  }
}

fn render_static(template: Template) -> Result(String, String) {
  let assert Static(path: path) = template

  let base_path = util.root_path()

  let full_path =
    [base_path, path]
    |> string.join(with: "/")

  case util.read_file(full_path) {
    Ok(document) -> Ok(document)

    // TODO: What is this error? 
    Error(error) -> {
      util.report([
        "Error: " <> string.inspect(Error(error)),
        "Base: " <> base_path,
        "Path: " <> path,
      ])

      Error("Unable to load file")
    }
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
