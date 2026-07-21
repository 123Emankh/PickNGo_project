'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('users', 'driver_status', {
      // ✅ حالة السائق الحقيقية (مخزّنة، مش محسوبة تخمينًا) - أساس Driver
      // Availability بكل النظام (لوحة الشركة/الأدمن/التوزيع الذكي لاحقًا)
      type: Sequelize.ENUM('Offline', 'Available', 'Busy'),
      allowNull: false,
      defaultValue: 'Offline',
    });
    await queryInterface.addColumn('users', 'current_lat', {
      // ✅ آخر موقع حي للسائق (مش عنوان التسجيل location_lat) - يتحدث بـ ping
      // دوري من تطبيق السائق، يُستخدم لتحديد "انقطع الاتصال" ولاحقًا Smart Assignment
      type: Sequelize.DECIMAL(10, 8),
      allowNull: true,
    });
    await queryInterface.addColumn('users', 'current_lng', {
      type: Sequelize.DECIMAL(11, 8),
      allowNull: true,
    });
    await queryInterface.addColumn('users', 'location_updated_at', {
      type: Sequelize.DATE,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('users', 'driver_status');
    await queryInterface.removeColumn('users', 'current_lat');
    await queryInterface.removeColumn('users', 'current_lng');
    await queryInterface.removeColumn('users', 'location_updated_at');
  },
};
