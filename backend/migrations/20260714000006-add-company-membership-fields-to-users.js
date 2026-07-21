'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('users', 'company_join_status', {
      // ✅ حالة طلب انضمام السائق لشركة التوصيل - منفصلة عن status العام
      // (اعتماد الأدمن للحساب). Pending لحد ما الشركة توافق/ترفض.
      type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'),
      allowNull: true,
    });
    await queryInterface.addColumn('users', 'last_active_at', {
      // ✅ آخر مرة المستخدم عمل طلب مصادَق عليه - نستخدمها كـ "heartbeat"
      // بسيط لتحديد حالة السائق (Available/Offline) بلوحة الشركة.
      type: Sequelize.DATE,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('users', 'company_join_status');
    await queryInterface.removeColumn('users', 'last_active_at');
  },
};
