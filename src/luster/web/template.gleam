import gleam/string
import gleam/list
import gleam/bbmustache as mustache

pub opaque type Template {
  Template(
    render: String,
    params: List(#(String, String)),
    file: String,
    base_path: String,
  )
}

pub fn new(path: String) -> Template {
  Template(
    render: "",
    params: [],
    file: "",
    base_path: build_path([root(), path]),
  )
}

pub fn from(template: Template, file: String) -> Template {
  // TODO: Validate file exists by returning Error
  assert Ok(render) =
    [template.base_path, file]
    |> build_path()
    |> read()

  Template(..template, file: file, render: render)
}

pub fn args(
  template: Template,
  replace key: String,
  with value: String,
) -> Template {
  let params = [#(key, value), ..template.params]
  Template(..template, params: params)
}

pub fn render(template: Template) -> String {
  let parameters =
    list.map(template.params, fn(p) { #(p.0, mustache.string(p.1)) })

  assert Ok(compiled) = mustache.compile(template.render)
  mustache.render(compiled, parameters)
}

fn build_path(path: List(String)) -> String {
  // TODO: Validate that it forms a valid URI
  string.join(path, with: "/")
}

external fn root() -> String =
  "Elixir.File" "cwd!"

external fn read(path: String) -> Result(String, error) =
  "Elixir.File" "read"