'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('otps', {
      otp_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      email: { type: Sequelize.STRING(100), allowNull: false },
      otp_code: { type: Sequelize.STRING(6), allowNull: false },
      type: {
        type: Sequelize.ENUM('Verification', 'ResetPassword', 'Login'),
        allowNull: true,
        defaultValue: 'Verification',
      },
      temp_token: { type: Sequelize.TEXT, allowNull: true },
      expires_at: { type: Sequelize.DATE, allowNull: false },
      is_used: { type: Sequelize.BOOLEAN, allowNull: true, defaultValue: false },
      attempts: { type: Sequelize.INTEGER, allowNull: true, defaultValue: 0 },
      ip_address: { type: Sequelize.STRING(45), allowNull: true },
      user_agent: { type: Sequelize.TEXT, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });
    await queryInterface.addIndex('otps', ['email']);
    await queryInterface.addIndex('otps', ['expires_at']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('otps');
  },
};
