'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('users', {
      user_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      full_name: { type: Sequelize.STRING(100), allowNull: false },
      email: { type: Sequelize.STRING(100), allowNull: false, unique: true },
      password: { type: Sequelize.STRING(255), allowNull: false },
      phone: { type: Sequelize.STRING(20), allowNull: true },
      profile_picture: { type: Sequelize.STRING(255), allowNull: true },
      role: {
        type: Sequelize.ENUM('Customer', 'Restaurant', 'Driver', 'Admin'),
        allowNull: false,
        defaultValue: 'Customer',
      },
      status: {
        type: Sequelize.ENUM('Pending', 'Approved', 'Rejected', 'Suspended'),
        allowNull: true,
        defaultValue: 'Pending',
      },
      location_lat: { type: Sequelize.DECIMAL(10, 8), allowNull: true },
      location_lng: { type: Sequelize.DECIMAL(11, 8), allowNull: true },
      location_address: { type: Sequelize.TEXT, allowNull: true },
      city: { type: Sequelize.STRING(50), allowNull: true },
      region: { type: Sequelize.STRING(50), allowNull: true },
      is_active: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: true },
      is_verified: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: false },
      last_login: { type: Sequelize.DATE, allowNull: true },
      reset_password_token: { type: Sequelize.STRING(255), allowNull: true },
      reset_password_expires: { type: Sequelize.DATE, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
      business_type: { type: Sequelize.STRING(30), allowNull: true },
      company_id: { type: Sequelize.INTEGER, allowNull: true },
    });

    // self-referential FK (سائق منضم لشركة توصيل = مستخدم تاني بنفس الجدول)
    await queryInterface.addConstraint('users', {
      fields: ['company_id'],
      type: 'foreign key',
      name: 'users_company_id_fkey',
      references: { table: 'users', field: 'user_id' },
      onDelete: 'SET NULL',
      onUpdate: 'CASCADE',
    });
  },

  async down(queryInterface) {
    await queryInterface.removeConstraint('users', 'users_company_id_fkey');
    await queryInterface.dropTable('users');
  },
};
