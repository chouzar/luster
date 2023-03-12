import gleam/result
import gleam/string
import gleam/list
import gleam/bbmustache.{CompileError} as mustache
import luster/util

pub opaque type Template {
  Template(
    render: String,
    params: List(#(String, String)),
    base_path: String,
    path: String,
  )
}

pub fn new(path: String) -> Template {
  Template(render: "", params: [], path: path, base_path: util.root_path())
}

pub fn args(
  template: Template,
  replace key: String,
  with value: String,
) -> Template {
  let params = [#(key, value), ..template.params]
  Template(..template, params: params)
}

pub fn render(template: Template) -> Result(String, CompileError) {
  case
    [template.base_path, template.path]
    |> string.join(with: "/")
    |> mustache.compile_file()
  {
    Ok(compiled) ->
      template.params
      |> list.map(fn(p) { #(p.0, mustache.string(p.1)) })
      |> mustache.render(compiled, _)
      |> Ok

    Error(error) -> {
      util.report([
        "Error: " <> string.inspect(Error(error)),
        "Base: " <> template.base_path,
        "Path: " <> template.path,
        "Params: " <> string.inspect(template.params),
      ])

      Error(error)
    }
  }
}
