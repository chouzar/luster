import gleam/result
import gleam/string
import gleam/list
import gleam/bbmustache.{CompileError} as mustache
import luster/util

pub opaque type Template {
  Layout(base_path: String, path: String, contents: List(#(String, Content)))
}

//Raw(value: String)

pub type Content {
  Template
  String
}

pub fn new(path: String) -> Template {
  Layout(base_path: util.root_path(), path: path, contents: [])
}

pub fn args(
  template: Template,
  replace key: String,
  with content: Content,
) -> Template {
  let Layout(contents: contents, ..) = template
  let contents = [#(key, content), ..contents]
  Layout(..template, contents: contents)
}
//
//pub fn render(template: Template) -> Result(String, CompileError) {
//  case
//    [template.base_path, template.path]
//    |> string.join(with: "/")
//    |> mustache.compile_file()
//  {
//    Ok(compiled) ->
//      template.params
//      |> list.map(fn(p) { #(p.0, mustache.string(p.1)) })
//      |> mustache.render(compiled, _)
//      |> Ok
//
//    Error(error) -> {
//      util.report([
//        "Error: " <> string.inspect(Error(error)),
//        "Base: " <> template.base_path,
//        "Path: " <> template.path,
//        "Params: " <> string.inspect(template.params),
//      ])
//
//      Error(error)
//    }
//  }
//}
//
