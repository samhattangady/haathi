var canvas = document.getElementById("haathi_canvas");
var ctx = canvas.getContext("2d");

const keys = [
  " ",
  "alt",
  "control",
  "shift",
  "enter",
  "tab",
  "arrowdown",
  "arrowup",
  "arrowleft",
  "arrowright",
  "backspace",
  "delete",
  "escape",
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "0",
  "[",
  "]",
  ";",
  "'",
  "\\",
  "/",
  ".",
  ",",
  "`",
];

const keycodes = {};
for (let i=0; i<keys.length; i++) keycodes[keys[i]] = i;

const getKeycode = (key) => {
  const code = keycodes[key.toLowerCase()];
  if (code === undefined) return keys.len + 20;  // return something out of scope.
  return code;
}

const wasmString = (ptr) => {
  const bytes = new Uint8Array(memory.buffer, ptr, memory.buffer.byteLength-ptr);
  let str = '';
  for (let i = 0; ; i++) {
    const c = String.fromCharCode(bytes[i]);
    if (c == '\0') break;
    str += c;
  }
  return str;
}

const clearCanvas = (color) => {
  ctx.fillStyle = wasmString(color);
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

const debugPrint = (ptr) => {
  console.log(wasmString(ptr));
}

const milliTimestamp = () => {
  return BigInt(Date.now());
}

const fillRect = (x, y, width, height) => {
  ctx.fillRect(x, y, width, height);
}

const roundRect = (x, y, width, height, radius) => {
  ctx.roundRect(x, y, width, height, radius);
}

const fillStyle = (color) => {
  ctx.fillStyle = wasmString(color);
}

const strokeStyle = (color) => {
  ctx.strokeStyle = wasmString(color);
}

const lineWidth = (width) => {
  ctx.lineWidth = width;
}

const beginPath = () => {
  ctx.beginPath();
}

const moveTo = (x, y) => {
  ctx.moveTo(x, y);
}

const lineTo = (x, y) => {
  ctx.lineTo(x, y);
}

const fill = () => {
  ctx.fill();
}

const stroke = () => {
  ctx.stroke();
}

const ellipse = (x, y, radius_x, radius_y, rotation, start_angle, end_angle, counter_clockwise) = {
  ctx.ellipse(x, y, radiusX, radiusY, rotation, startAngle, endAngle);
}

var api = {
  fillRect,
  roundRect,
  clearCanvas,
  debugPrint,
  milliTimestamp,
  fillStyle,
  strokeStyle,
  beginPath,
  moveTo,
  lineTo,
  lineWidth,
  fill,
  stroke,
  ellipse,
};
