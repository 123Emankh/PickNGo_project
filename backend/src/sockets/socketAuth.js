// src/sockets/socketAuth.js
// نفس منطق middleware/auth.js بس لـ Socket.io handshake بدل Express request.
// العميل بيبعث التوكن بـ socket.handshake.auth.token وقت الاتصال (مش عبر Header زي REST).
const { verifyUserToken, AuthError } = require('../utils/verifyUserToken');

async function socketAuth(socket, next) {
  try {
    const token = socket.handshake.auth && socket.handshake.auth.token;
    const user = await verifyUserToken(token);
    socket.user = user; // نفس شكل req.user: { user_id, email, role, status }
    next();
  } catch (error) {
    if (error instanceof AuthError) {
      return next(new Error(error.message));
    }
    console.error('Socket auth error:', error);
    next(new Error('Authentication error'));
  }
}

module.exports = socketAuth;
