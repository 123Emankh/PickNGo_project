'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('restaurants', {
      restaurant_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      category_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'categories', key: 'category_id' },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      },
      image_url: { type: Sequelize.STRING(255), allowNull: true },
      name: { type: Sequelize.STRING(100), allowNull: false },
      description: { type: Sequelize.TEXT, allowNull: true },
      cuisine_type: { type: Sequelize.STRING(50), allowNull: true },
      logo: { type: Sequelize.STRING(255), allowNull: true },
      cover_image: { type: Sequelize.STRING(255), allowNull: true },
      address: { type: Sequelize.TEXT, allowNull: false },
      location_lat: { type: Sequelize.DECIMAL(10, 8), allowNull: false },
      location_lng: { type: Sequelize.DECIMAL(11, 8), allowNull: false },
      city: { type: Sequelize.STRING(50), allowNull: false },
      region: { type: Sequelize.STRING(50), allowNull: false },
      phone: { type: Sequelize.STRING(20), allowNull: false },
      email: { type: Sequelize.STRING(100), allowNull: true },
      opening_time: { type: Sequelize.TIME, allowNull: true },
      closing_time: { type: Sequelize.TIME, allowNull: true },
      delivery_fee: { type: Sequelize.DECIMAL(10, 2), allowNull: true, defaultValue: 0.0 },
      minimum_order: { type: Sequelize.DECIMAL(10, 2), allowNull: true, defaultValue: 0.0 },
      rating: { type: Sequelize.DECIMAL(3, 2), allowNull: true, defaultValue: 0.0 },
      review_count: { type: Sequelize.INTEGER, allowNull: true, defaultValue: 0 },
      is_open: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: true },
      is_active: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: true },
      approval_status: {
        type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'),
        allowNull: true,
        defaultValue: 'Pending',
      },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
      rejection_reason: { type: Sequelize.TEXT, allowNull: true },
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('restaurants');
  },
};
