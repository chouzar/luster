import gleam/int
import gleam/option.{None, Option, Some}
import gleam/string
import gleam/string_builder
import gleam/list
import gleam/map.{Map}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import luster/server/middleware.{FormFields}
import luster/server/mime
import luster/server/template
import luster/battleline.{GameState}

pub fn index(_: Request(FormFields)) -> Response(String) {
  let state = load("1234567890")

  response.new(200)
  |> response.prepend_header("content-type", mime.html)
  |> response.set_body(render_index(state))
}

pub fn favicon(_: Request(FormFields)) -> Response(String) {
  response.new(200)
  |> response.set_body(
    template.new(["html", "battleline"])
    |> template.from(["favicon.ico"])
    |> template.render(),
  )
}

pub fn css(_: Request(FormFields)) -> Response(String) {
  response.new(200)
  |> response.prepend_header("content-type", mime.css)
  |> response.set_body(
    template.new(["html", "battleline"])
    |> template.from(["styles.css"])
    |> template.render(),
  )
}

const html_path = ["html", "battleline"]

fn render_index(state: GameState) -> String {
  template.new(html_path)
  |> template.from(["index.html"])
  |> template.args(replace: "card-draw-pile", with: render_draw_pile(state))
  |> template.render()
}

fn render_draw_pile(state: GameState) -> String {
  let size = case list.length(state.deck) {
    size if size > 50 -> 12
    size if size > 40 -> 10
    size if size > 30 -> 8
    size if size > 20 -> 6
    size if size > 10 -> 4
    size if size > 0 -> 2
    0 -> 0
  }

  string_builder.to_string({
    use builder, times <- repeat(size, string_builder.new())
    let pixels = { times - size } * 1
    let top = int.to_string(pixels)
    let right = int.to_string(pixels * -1)
    let styles = string.join(["top:", top, "px;", "right:", right, "px;"], "")

    let card =
      template.new(html_path)
      |> template.from(["card_back.html"])
      |> template.args(replace: "background", with: "clouds")
      |> template.args(replace: "styles", with: styles)
      |> template.render()

    string_builder.append(builder, card)
  })
}

fn load(_id: String) -> GameState {
  // We load the state from a memory location
  battleline.new_game()
}

fn repeat(times: Int, acc: acc, fun: fn(acc, Int) -> acc) -> acc {
  case times {
    times if times > 0 -> repeat(times - 1, fun(acc, times), fun)
    0 -> acc
  }
}
// Go Next mile by doing a View type for component
//type Pattern {
//  Cloud
//  Diamond
//}
//
//type Position {
//  Position(x: Int, y: Int)
//}
//
//type RenderCard {
//  Back(pattern: Pattern, position: Option(Position))
//}
