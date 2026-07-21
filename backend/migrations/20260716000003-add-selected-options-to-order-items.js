'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('order_items', 'selected_options', {
      // ✅ سناب شوت لمجموعات المواصفات المخصصة المختارة وقت الطلب:
      // [{group_id, group_name, value_id, label, price}, ...]
      type: Sequelize.JSON,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('order_items', 'selected_options');
  },
};
