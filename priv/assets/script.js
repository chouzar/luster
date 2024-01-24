const p1_hand = document.querySelector(".board .hand:nth-child(1)");
const p2_hand = document.querySelector(".board .hand:nth-child(2)");

const exampleSocket = new WebSocket(
  "wss://localhost:4444/events",
  "protocolOne",
);

exampleSocket.onopen = (_event) => {
  exampleSocket.send("start: " + self.crypto.randomUUID());
};

exampleSocket.onmessage = (event) => {
  console.log(event);
  console.log(event.data);
  
  p1_hand.insertAdjacentHTML("beforeend", "<div>Hello World!</div>")
};