import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/string
import gleam/list
import gleam/map.{Map}
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{Request}
import gleam/http/response
import gleam/bbmustache as mustache
import mist
import gleam/io

pub opaque type Template {
  Template(
    render: String,
    params: List(#(String, String)),
    path: String,
    base_path: String,
  )
}

pub fn new(path: List(String)) -> Template {
  Template(
    render: "",
    params: [],
    path: "",
    base_path: build_path([root(), ..path]),
  )
}

pub fn from(template: Template, path: List(String)) -> Template {
  let path = build_path(path)

  assert Ok(render) =
    [template.base_path, path]
    |> build_path()
    |> read()

  Template(..template, path: path, render: render)
}

pub fn with(template: Template, params: List(#(String, String))) -> Template {
  let parameters = list.map(params, fn(p) { #(p.0, mustache.string(p.1)) })

  assert Ok(compiled) = mustache.compile(template.render)
  let render = mustache.render(compiled, parameters)
  Template(..template, params: params, render: render)
}

pub fn render(template: Template) -> String {
  template.render
}

fn build_path(path: List(String)) -> String {
  string.join(path, with: "/")
}

external fn root() -> String =
  "Elixir.File" "cwd!"

external fn read(path: String) -> Result(String, error) =
  "Elixir.File" "read"
