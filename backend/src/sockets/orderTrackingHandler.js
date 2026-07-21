// src/sockets/orderTrackingHandler.js
const { Order, Restaurant } = require('../models');

function roomName(orderId) {
  return `order:${orderId}`;
}

/**
 * بيتأكد إنه المستخدم المتصل هو فعلاً طرف بهاد الطلب (زبون / سائق مسند / صاحب المتجر / أدمن)
 * قبل ما يسمحله ينضم لغرفة الطلب - نفس منطق الصلاحيات المستخدم بـ updateOrderStatus بالكونترولر.
 */
async function canAccessOrder(order, user) {
  if (!order) return false;
  if (user.role === 'Admin') return true;
  if (user.role === 'Customer') return order.customer_id === user.user_id;
  if (user.role === 'Driver') return order.driver_id === user.user_id;
  if (user.role === 'Restaurant') {
    const store = await Restaurant.findOne({ where: { user_id: user.user_id } });
    return !!store && store.restaurant_id === order.restaurant_id;
  }
  return false;
}

function registerOrderTrackingHandler(io, socket) {
  socket.on('order:join', async ({ order_id } = {}) => {
    try {
      const order = await Order.findByPk(order_id);
      const allowed = await canAccessOrder(order, socket.user);
      if (!allowed) {
        return socket.emit('order:error', { message: 'Not authorized to track this order' });
      }
      socket.join(roomName(order_id));
    } catch (error) {
      console.error('❌ order:join error:', error);
      socket.emit('order:error', { message: 'Server error while joining order room' });
    }
  });

  socket.on('order:leave', ({ order_id } = {}) => {
    if (order_id) socket.leave(roomName(order_id));
  });

  socket.on('driver:location', async ({ order_id, lat, lng } = {}) => {
    try {
      if (socket.user.role !== 'Driver') return;
      if (typeof lat !== 'number' || typeof lng !== 'number') return;

      const order = await Order.findByPk(order_id);
      if (!order || order.driver_id !== socket.user.user_id) {
        return socket.emit('order:error', { message: 'You are not assigned to this order' });
      }

      const updatedAt = new Date();
      await order.update({
        driver_current_lat: lat,
        driver_current_lng: lng,
        driver_location_updated_at: updatedAt
      });

      socket.to(roomName(order_id)).emit('driver:location', {
        order_id,
        lat,
        lng,
        updated_at: updatedAt
      });
    } catch (error) {
      console.error('❌ driver:location error:', error);
    }
  });
}

module.exports = registerOrderTrackingHandler;
