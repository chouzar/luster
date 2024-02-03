const session = document.querySelector("meta[name='session']").content;
const body = document.querySelector("body");

const socket = new WebSocket("wss://localhost:4444/events/" + session);

socket.onopen = (_event) => {
};

socket.onmessage = (event) => {
  let [html, ...rest] = event.data.split("\n\n")
  body.innerHTML = html
};

window.addEventListener('click', (event) => {
  console.log(event.target.dataset.event)
  if (event.target.dataset.event) {
    socket.send(new Blob([event.target.dataset.event]));
  }
});