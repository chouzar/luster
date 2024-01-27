const session = document.querySelector("meta[name='session']").content;
const body = document.querySelector("body");

const socket = new WebSocket("wss://localhost:4444/events");

socket.onopen = (_event) => {
  socket.send("session:" + session)
};

socket.onmessage = (event) => {
  let [html, ...rest] = event.data.split("\n\n")
  body.innerHTML = html
};

window.addEventListener('click', (event) => {
  if (event.target.dataset.event) {
    const action = event.target.dataset.event
    const data = JSON.stringify(event.target.dataset);
    socket.send(new Blob([action, "\n\n", data]));
  }
});