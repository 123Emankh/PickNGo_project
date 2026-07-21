'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('order_items', 'addons', {
      // ✅ سناب شوت (snapshot) للإضافات المختارة وقت الطلب: [{id, name, price}]
      type: Sequelize.JSON,
      allowNull: true,
    });
    await queryInterface.addColumn('order_items', 'special_requests', {
      // ✅ سناب شوت للطلبات الخاصة المختارة وقت الطلب: ["No Onions", ...]
      type: Sequelize.JSON,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('order_items', 'addons');
    await queryInterface.removeColumn('order_items', 'special_requests');
  },
};
