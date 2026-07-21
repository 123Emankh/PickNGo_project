'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('orders', 'status_history', {
      // ✅ سجل زمني حقيقي لكل تغيير حالة: [{status, at}, ...] - أساس شاشة
      // التتبع "Story timeline". أول عنصر بينكتب وقت الإنشاء (createOrder)،
      // وبعدين كل استدعاء لـ updateOrderStatus بيضيف عنصر جديد.
      type: Sequelize.JSON,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('orders', 'status_history');
  },
};
