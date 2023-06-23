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

const fillRect = (x, y, width, height, color) => {
  ctx.fillStyle = wasmString(color);
  ctx.fillRect(x, y, width, height);
}

const clearCanvas = (color) => {
  ctx.fillStyle = wasmString(color);
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

const debugPrint = (ptr) => {
  console.log(wasmString(ptr));
}

var api = {
  fillRect,
  clearCanvas,
  debugPrint,
};
