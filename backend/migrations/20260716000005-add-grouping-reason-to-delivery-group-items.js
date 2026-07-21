'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('delivery_group_items', 'matched_with_order_id', {
      // ✅ الطلب اللي انطابق معه وقت التجميع - null لأول عضو (anchor) بالمجموعة
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'orders', key: 'order_id' },
    });
    await queryInterface.addColumn('delivery_group_items', 'store_distance_km', {
      type: Sequelize.DECIMAL(6, 3),
      allowNull: true,
    });
    await queryInterface.addColumn('delivery_group_items', 'delivery_distance_km', {
      type: Sequelize.DECIMAL(6, 3),
      allowNull: true,
    });
    await queryInterface.addColumn('delivery_group_items', 'time_difference_minutes', {
      type: Sequelize.INTEGER,
      allowNull: true,
    });
    await queryInterface.addColumn('delivery_group_items', 'rules_satisfied', {
      // ✅ مصفوفة نصوص: ["same_customer","store_distance","delivery_distance","time_window"]
      type: Sequelize.JSON,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('delivery_group_items', 'matched_with_order_id');
    await queryInterface.removeColumn('delivery_group_items', 'store_distance_km');
    await queryInterface.removeColumn('delivery_group_items', 'delivery_distance_km');
    await queryInterface.removeColumn('delivery_group_items', 'time_difference_minutes');
    await queryInterface.removeColumn('delivery_group_items', 'rules_satisfied');
  },
};
