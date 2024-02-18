const session = document.querySelector("meta[name='session']").content;
const body = document.querySelector("body");

if (session) {
  const socket = new WebSocket("wss://localhost:4444/events/" + session);

  socket.onmessage = (event) => {
    let [html, ...rest] = event.data.split("\n\n")
    body.innerHTML = html
  };

  socket.onclose = (event) => {
    console.log("disconnected cause server halted");
    // TODO: reload page here
  };

  window.addEventListener('click', (event) => {
    if (event.target.dataset.event) {
      socket.send(new Blob([event.target.dataset.event]));
    }
  });
}
