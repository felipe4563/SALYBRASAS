const { Server } = require('socket.io');

let _io = null;

function init(server) {
  const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:5173')
    .split(',')
    .map(o => o.trim());

  _io = new Server(server, {
    cors: {
      // Acepta los orígenes configurados + el agente de impresión (sin origin)
      origin: (origin, cb) => {
        if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
        cb(new Error('socket.io CORS: ' + origin));
      },
      methods: ['GET', 'POST'],
    },
  });
  _io.on('connection', (socket) => {
    console.log('Socket conectado:', socket.id);
    socket.on('disconnect', () => console.log('Socket desconectado:', socket.id));
  });
  return _io;
}

function emitir(evento, datos = {}) {
  if (_io) _io.emit(evento, datos);
}

module.exports = { init, emitir };
