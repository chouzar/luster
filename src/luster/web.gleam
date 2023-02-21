import gleam/http.{Get, Post}
import gleam/http/request
import luster/server
import luster/web/general
import luster/web/chat
import luster/web/battleline

pub fn run() -> Nil {
  server.run(8088, handle_request)
}

fn handle_request(request) {
  case request.method, request.path {
    Get, "/" -> general.index(request)

    Get, "/chat" -> chat.index(request)
    Post, "/chat/send-message" -> chat.send_message(request)
    Get, "/chat/click/example" -> chat.click_example(request)
    Get, "/chat/click/lazy" -> chat.click_example_lazy(request)

    method, _path ->
      case method, request.path_segments(request) {
        Get, ["battleline"] -> battleline.index(request)
        Post, ["battleline", "draw-card"] -> battleline.draw_card(request)
        Post, ["battleline", "draw-special"] -> battleline.draw_card(request)

        Get, ["battleline", "assets", ..path] -> battleline.assets(path)
      }

    _, _ -> general.error(request)
  }
}
