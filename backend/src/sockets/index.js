// src/sockets/index.js
const { Server } = require('socket.io');
const socketAuth = require('./socketAuth');
const registerOrderTrackingHandler = require('./orderTrackingHandler');
const { startStalenessSweep } = require('../services/driverStatusService');
const { startAssignmentSweep } = require('../services/assignmentService');
const { startGroupAssignmentSweep } = require('../services/groupAssignmentService');

let io = null;

/**
 * ينشئ سيرفر Socket.io فوق نفس http server يلي Express شغال عليه.
 * لازم تنادى مرة وحدة من server.js قبل ما تعمل listen.
 */
function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: '*' }
  });

  io.use(socketAuth);

  io.on('connection', (socket) => {
    console.log(`🔌 Socket connected: user_id=${socket.user.user_id} role=${socket.user.role}`);

    registerOrderTrackingHandler(io, socket);

    // ✅ Phase 4 - نظام الإشعارات: غرفة عامة لأي مستخدم مسجّل دخول (بغض النظر
    // عن الدور) - notificationService.createNotification بتبث عليها حدث
    // notification:new لحظة إنشاء أي إشعار جديد له
    socket.join(`notifications:${socket.user.user_id}`);

    // ✅ غرف بث حالة السائق (driver:status) - كل مستخدم بينضم لغرفته المناسبة
    // وقت الاتصال، وdriverStatusService بيبثّ عليها لما أي حالة تتغيّر.
    if (socket.user.role === 'Admin') {
      socket.join('driver-status:admin');
    }
    if (socket.user.role === 'Driver') {
      // بتغطي الحالتين: السائق نفسه (يشوف حالته لحظيًا)، ولو هو شركة توصيل
      // (غرفة سائقيها التابعين إلها بتبث هون كمان)
      socket.join(`driver-status:self:${socket.user.user_id}`);
      socket.join(`driver-status:company:${socket.user.user_id}`);
      // ✅ Phase 3 - Smart Assignment: غرفة خاصة يبعثلها assignmentService
      // عرض تعيين (order:offer) لما هاد السائق بالذات يتم اختياره
      socket.join(`driver-orders:${socket.user.user_id}`);
    }

    socket.on('disconnect', () => {
      console.log(`🔌 Socket disconnected: user_id=${socket.user.user_id}`);
    });
  });

  startStalenessSweep(io);
  startAssignmentSweep(io);
  startGroupAssignmentSweep(io);

  console.log('🔌 Socket.io initialized');
  return io;
}

/**
 * يرجع instance الـ io الحالي (أو null لو لسا ما انعمل init) -
 * الكونترولرز بتنادي هاي الدالة وقت الحاجة (بعد ما يكون السيرفر شغال) بدل ما تعمل import مباشر
 * لتفادي مشاكل الترتيب/circular imports.
 */
function getIo() {
  return io;
}

module.exports = { initSocket, getIo };
