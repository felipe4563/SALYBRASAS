import { io } from 'socket.io-client';
import { BASE_URL } from './api/configuracion';

const socket = io(BASE_URL, {
  autoConnect: true,
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionAttempts: Infinity,
});

export default socket;
