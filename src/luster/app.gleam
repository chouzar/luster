import gleam/http
import luster/server
import luster/app/general
import luster/app/chat
import luster/app/battleline

pub fn run() -> Nil {
  server.run(8088, handle_request)
}

fn handle_request(request) {
  case request.method, request.path {
    http.Get, "/" -> general.index(request)

    http.Get, "/chat" -> chat.index(request)
    http.Post, "/chat/send-message" -> chat.send_message(request)
    http.Get, "/chat/click/example" -> chat.click_example(request)
    http.Get, "/chat/click/lazy" -> chat.click_example_lazy(request)

    http.Get, "/battleline" -> battleline.index(request)
    http.Get, "/battleline/css" -> battleline.css(request)
    http.Get, "/battleline/favicon" -> battleline.favicon(request)
    http.Post, "/battleline/draw-card" -> battleline.draw_card(request)
    http.Post, "/battleline/draw-special" -> battleline.draw_card(request)

    _, _ -> general.error(request)
  }
}
