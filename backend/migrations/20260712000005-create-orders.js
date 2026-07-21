'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('orders', {
      order_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      customer_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      restaurant_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'restaurants', key: 'restaurant_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      driver_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      },
      order_number: { type: Sequelize.STRING(20), allowNull: false, unique: true },
      status: {
        type: Sequelize.ENUM(
          'Pending', 'Confirmed', 'Preparing', 'Ready', 'PickedUp', 'Delivered', 'Cancelled', 'Refunded'
        ),
        allowNull: true,
        defaultValue: 'Pending',
      },
      total_amount: { type: Sequelize.DECIMAL(10, 2), allowNull: false },
      delivery_fee: { type: Sequelize.DECIMAL(10, 2), allowNull: true, defaultValue: 0.0 },
      tax: { type: Sequelize.DECIMAL(10, 2), allowNull: true, defaultValue: 0.0 },
      discount: { type: Sequelize.DECIMAL(10, 2), allowNull: true, defaultValue: 0.0 },
      final_amount: { type: Sequelize.DECIMAL(10, 2), allowNull: false },
      delivery_address: { type: Sequelize.TEXT, allowNull: false },
      delivery_lat: { type: Sequelize.DECIMAL(10, 8), allowNull: true },
      delivery_lng: { type: Sequelize.DECIMAL(11, 8), allowNull: true },
      special_instructions: { type: Sequelize.TEXT, allowNull: true },
      estimated_delivery_time: { type: Sequelize.INTEGER, allowNull: true },
      actual_delivery_time: { type: Sequelize.INTEGER, allowNull: true },
      payment_method: {
        type: Sequelize.ENUM('Cash', 'CreditCard', 'DebitCard', 'Wallet'),
        allowNull: false,
      },
      payment_status: {
        type: Sequelize.ENUM('Pending', 'Paid', 'Failed', 'Refunded'),
        allowNull: true,
        defaultValue: 'Pending',
      },
      payment_id: { type: Sequelize.STRING(100), allowNull: true },
      order_time: { type: Sequelize.DATE, allowNull: true },
      delivery_time: { type: Sequelize.DATE, allowNull: true },
      completed_time: { type: Sequelize.DATE, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
      driver_current_lat: { type: Sequelize.DECIMAL(10, 8), allowNull: true },
      driver_current_lng: { type: Sequelize.DECIMAL(11, 8), allowNull: true },
      driver_location_updated_at: { type: Sequelize.DATE, allowNull: true },
      payment_checkout_id: { type: Sequelize.STRING(100), allowNull: true },
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('orders');
  },
};
