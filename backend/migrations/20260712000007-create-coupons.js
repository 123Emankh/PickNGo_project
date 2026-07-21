'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('coupons', {
      coupon_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      restaurant_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'restaurants', key: 'restaurant_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      created_by: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      code: { type: Sequelize.STRING(30), allowNull: false, unique: true },
      discount_type: { type: Sequelize.ENUM('Percentage', 'Fixed'), allowNull: false },
      discount_value: { type: Sequelize.DECIMAL(10, 2), allowNull: false },
      min_order_amount: { type: Sequelize.DECIMAL(10, 2), allowNull: true, defaultValue: 0.0 },
      max_discount_amount: { type: Sequelize.DECIMAL(10, 2), allowNull: true },
      valid_from: { type: Sequelize.DATE, allowNull: true },
      valid_until: { type: Sequelize.DATE, allowNull: true },
      usage_limit: { type: Sequelize.INTEGER, allowNull: true },
      usage_limit_per_customer: { type: Sequelize.INTEGER, allowNull: true, defaultValue: 1 },
      used_count: { type: Sequelize.INTEGER, allowNull: true, defaultValue: 0 },
      is_active: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('coupons');
  },
};
