import nakai/html
import nakai/html/attrs

pub fn view(
  session_id: String,
  live_session: Bool,
  body: html.Node(a),
) -> html.Node(a) {
  let live_session = case live_session {
    True -> "true"
    False -> ""
  }

  html.Html([], [
    html.Head([
      html.title("Line Poker"),
      html.meta([attrs.name("viewport"), attrs.content("width=device-width")]),
      html.meta([attrs.name("session-id"), attrs.content(session_id)]),
      html.meta([attrs.name("live-session"), attrs.content(live_session)]),
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
