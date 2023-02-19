import gleam/http
import luster/server
import luster/app/general
import luster/app/chat

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

    _, _ -> general.error(request)
  }
}
