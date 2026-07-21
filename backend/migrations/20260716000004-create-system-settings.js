'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('system_settings', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      grouped_delivery_enabled: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: true },
      // كل مسافات بالكيلومتر
      max_store_distance: { type: Sequelize.DECIMAL(6, 2), allowNull: false, defaultValue: 0.1 },
      max_delivery_distance: { type: Sequelize.DECIMAL(6, 2), allowNull: false, defaultValue: 0.1 },
      // بالدقايق
      max_time_between_orders: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 10 },
      max_orders_per_group: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 4 },
      max_stores_per_trip: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 4 },
      // محجوز - ما في نظام تقييم سائقين بالمشروع لسا، الحقل مخزّن بس بدون تفعيل
      minimum_driver_rating: { type: Sequelize.DECIMAL(2, 1), allowNull: false, defaultValue: 0 },
      auto_assign_driver: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('system_settings');
  },
};
