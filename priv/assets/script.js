const session_id = document.querySelector("meta[name='session-id']").content;
const is_live = document.querySelector("meta[name='live-session']").content;

if (session_id && is_live) {
  const body = document.querySelector("body");
  const socket = new WebSocket("wss://localhost:4444/events/" + session_id);

  socket.onmessage = (event) => {
    let [html, ...rest] = event.data.split("\n\n")
    body.innerHTML = html
  };

  window.addEventListener('click', (event) => {
    if (event.target.dataset.event) {
      socket.send(new Blob([event.target.dataset.event]));
    }
  });
}