var canvas = document.getElementById("haathi_canvas");
var ctx = canvas.getContext("2d");

const fillRect = (x, y, width, height, color) => {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, width, height);
}

var api = {
  fillRect,
};
