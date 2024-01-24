import nakai/html
import nakai/html/attrs

pub fn view(body: html.Node(a)) -> html.Node(a) {
  html.Html([], [
    html.Head([
      html.title("Line Poker"),
      html.meta([attrs.name("viewport"), attrs.content("width=device-width")]),
      html.link([
        attrs.rel("icon"),
        attrs.type_("image/x-icon"),
        attrs.defer(),
        attrs.href("/assets/favicon.ico"),
      ]),
      html.link([
        attrs.rel("stylesheet"),
        attrs.type_("text/css"),
        attrs.defer(),
        attrs.href("/assets/styles.css"),
      ]),
      html.Element(
        tag: "script",
        attrs: [attrs.src("/assets/script.js"), attrs.defer()],
        children: [],
      ),
    ]),
    html.Body([], [body]),
  ])
}
