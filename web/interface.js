
const bigToUint8Array = (big) => {
  const big0 = BigInt(0)
  const big1 = BigInt(1)
  const big8 = BigInt(8)
  if (big < big0) {
    const bits = (BigInt(big.toString(2).length) / big8 + big1) * big8
    const prefix1 = big1 << bits
    big += prefix1
  }
  let hex = big.toString(16)
  if (hex.length % 2) {
    hex = '0' + hex
  }
  const len = hex.length / 2
  const u8 = new Uint8Array(len)
  let i = 0
  let j = 0
  while (i < len) {
    u8[i] = parseInt(hex.slice(j, j + 2), 16)
    i += 1
    j += 2
  }
  return u8
}

const u8ToNumber = (array) => {
  let number = 0;
  let pow = 0;
  for (let i = array.length - 1; i >= 0; i--) {
    number += array[i] * (256 ** pow);
    pow += 1;
  }
  return number;
}

const getFileText = (path) => {
    let request = new XMLHttpRequest();
    // TODO (12 May 2022 sam): This is being deprecated... How can we do sync otherwise?
    request.open('GET', path, false);
    request.send(null);
    if (request.status !== 200) return false;
    return request.responseText;
}

const readWebFile = (path, ptr, len) => {
    path = wasmString(path);
    // read text from URL location
    const text = getFileText(path);
    if (text === false) return false;
    if (text.length != len) {
      console.log("file length does not match requested length", path, len);
      return false;
    }
    const fileContents = new Uint8Array(memory.buffer, ptr, len);
    for (let i=0; i<len; i++) {
      fileContents[i] = text.charCodeAt(i);
    }
    console.log("returning file ", path);
    return true;    
}

const getWebFileSize= (path) => {
    path = wasmString(path);
    // read text from URL location
    const text = getFileText(path);
    if (text === false) return -1;
    return text.length;
}

const getStorageText = (path) => {
    try {
    const text = localStorage.getItem(path);
    if (text === null) return false;
    return text;
    } catch {
      return false;
    }
}

const getStorageFileSize = (path) => {
  path = wasmString(path);
  const text = getStorageText(path);
  if (text === false) return -1;
  return text.length;
}

const readStorageFile = (path, ptr, len) => {
    path = wasmString(path);
    // read text from URL location
    const text = getStorageText(path);
    if (text === false) return false;
    if (text.length != len) {
      console.log("file length does not match requested length", path, len);
      return false;
    }
    const fileContents = new Uint8Array(memory.buffer, ptr, len);
    for (let i=0; i<len; i++) {
      fileContents[i] = text.charCodeAt(i);
    }
    return true;    
}

const writeStorageFile = (path, text) => {
    path = wasmString(path);
    text = wasmString(text);
    try {
      localStorage.setItem(path, text);
    } catch {
      return false;
    }
    return true;
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

const consoleLog = (value, len) => {
  const bytes = new Uint8Array(memory.buffer, value, len);
  let str = '';
  for (let i = 0; i < len; i++) {
    str += String.fromCharCode(bytes[i]);
  }
  console.log('zig1:', str);
  // console.log('zig2:', getString(value));
};

const console_log = (value) => {
  console.log('zig2:', wasmString(value));
}

const milliTimestamp = () => {
  return BigInt(Date.now());
}

// we choose to always init the webgl context.
var canvas = document.getElementById("webgl_canvas");
var gl = canvas.getContext("webgl2", {alpha: false, antialias: true});

// webgl does not store the state like opengl. So we have to do some of that work.
const glShaders = [];
const glPrograms = [];
const glVertexArrays = [];
const glBuffers = [];
const glTextures = [];
const glUniformLocations = [];

const glClearColor = (r,g,b,a) => {
  gl.clearColor(r, g, b, a);
}

const glClear = (mask) => {
  gl.clear(mask);
} 

const glBindFramebuffer = (target, framebuffer) => {
  let fb = null;
  if (framebuffer != 0) fb = framebuffer;
  gl.bindFramebuffer(target, fb)
}

const glUseProgram = (program) => {
  gl.useProgram(glPrograms[program]);
}

const glViewport = (x, y, width, height) => {
  gl.viewport(x, y, width, height)
}

const glEnable = (cap) => {
  gl.enable(cap);
}

const glBlendFunc = (sfactor, dfactor) => {
  gl.blendFunc(sfactor, dfactor);
}

// might need fix
const glGetUniformLocation = (programId, webText) => {
  glUniformLocations.push(gl.getUniformLocation(glPrograms[programId], wasmString(webText)));
  return glUniformLocations.length - 1;
};

const glUniform1i = (uniform, v0) => {
  gl.uniform1i(glUniformLocations[uniform], glUniformLocations[v0]);
}

const glCreateVertexArray = () => {
  glVertexArrays.push(gl.createVertexArray());
  return glVertexArrays.length - 1;
};

const glGenVertexArrays = (num, dataPtr) => {
  const vaos = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateVertexArray();
    vaos[n] = b;
  }
}

const glActiveTexture = (texture) => {
  gl.activeTexture(texture);
}

const glBindVertexArray = (va) => {
  gl.bindVertexArray(glVertexArrays[va]);
}

const glBindBuffer = (target, buffer) => {
  gl.bindBuffer(target, glBuffers[buffer]);
}

const glBufferData = (target, size, data, usage) => {
  if (target == 34962) { // GL_ARRAY_BUFFER
    size = Number(size);
    const buffer = new Float32Array(memory.buffer, data, size);
    gl.bufferData(target, buffer, usage);
  }
  if (target ==0x8893 ) { // GL_ELEMENT_ARRAY_BUFFER
    size = Number(size);
    const buffer = new Uint32Array(memory.buffer, data, size);
    gl.bufferData(target, buffer, usage);
  }

}

const glDrawElements = (mode, count, type, offset) => {
  gl.drawElements(mode, count, type, offset);
}

const glGenBuffers = (num, dataPtr) => {
  const buffers = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateBuffer();
    buffers[n] = b;
  }
}

const glVertexAttribPointer = (attribLocation, size, type, normalize, stride, offset) => {
  gl.vertexAttribPointer(attribLocation, size, type, normalize, stride, offset);
}

const glEnableVertexAttribArray = (x) => {
  gl.enableVertexAttribArray(x);
}

const glGenTextures = (num, dataPtr) => {
  const textures = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateTexture();
    textures[n] = b;
  }
}

const glTexImage2D = (target, level, internalFormat, width, height, border, format, type, dataPtr) => {
  const data = new Uint8Array(memory.buffer, dataPtr, width*height);
  gl.texImage2D(target, level, internalFormat, width, height, border, format, type, data);
};

const glTexParameteri = (target, pname, param) => {
  gl.texParameteri(target, pname, param);
}

const glCreateShader = (type) => {
  let shader = gl.createShader(type);
  glShaders.push(shader);
  return glShaders.length - 1;
}

const glShaderSource = (shader, count, data, len) => {
  if (count != 1) console.log("we only support count = 1 for glShaderSource");
  const source = new Uint8Array(memory.buffer, data, len);
  let str = '';
  for (let i = 0; i < len; i++) {
    str += String.fromCharCode(source[i]);
  }
  gl.shaderSource(glShaders[shader], str);
}

const glCompileShader = (shader) => {
  gl.compileShader(glShaders[shader]);
}

const glCreateProgram = () => {
  let program = gl.createProgram();
  glPrograms.push(program);
  return glPrograms.length - 1;
}

const glAttachShader = (program, shader) => {
  gl.attachShader(glPrograms[program], glShaders[shader]);
}

const glLinkProgram = (program) => {
  gl.linkProgram(glPrograms[program]);
}

const glDeleteShader = (shader) => {
  // eh who will delete and all
}

const glCreateBuffer = () => {
  glBuffers.push(gl.createBuffer());
  return glBuffers.length - 1;
}

const glCreateTexture = () => {
  glTextures.push(gl.createTexture());
  return glTextures.length - 1;
};

const glBindTexture = (target, textureId) => {
  gl.bindTexture(target, glTextures[textureId]);
}

const glDepthFunc = (f) => {
  gl.depthFunc(f);
}

const glColorMask = (r,g,b,a) => {
  gl.colorMask(r,g,b,a);
}

const glDisable = (f) => {
  gl.disable(f);
}

var api = {
  consoleLogS: consoleLog,
  console_log,
  readWebFile,
  getWebFileSize,
  readStorageFile,
  getStorageFileSize,
  writeStorageFile,
  milliTimestamp,
  glClearColor,
  glClear,
  glBindFramebuffer,
  glUseProgram,
  glViewport,
  glEnable,
  glBlendFunc,
  glGetUniformLocation,
  glUniform1i,
  glActiveTexture,
  glBindTexture,
  glBindVertexArray,
  glBindBuffer,
  glBufferData,
  glDrawElements,
  glGenBuffers,
  glGenVertexArrays,
  glVertexAttribPointer,
  glEnableVertexAttribArray,
  glGenTextures,
  glTexImage2D,
  glTexParameteri,
  glCreateShader,
  glShaderSource,
  glCompileShader,
  glCreateProgram,
  glAttachShader,
  glLinkProgram,
  glDeleteShader,
  glCreateVertexArray,
  glCreateBuffer,
  glCreateTexture,
  glDepthFunc,
  glColorMask,
  glDisable,
}

