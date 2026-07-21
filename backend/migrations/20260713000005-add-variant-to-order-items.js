'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('order_items', 'variant_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'product_variants', key: 'variant_id' },
      onDelete: 'SET NULL',
      onUpdate: 'CASCADE',
    });
    await queryInterface.addColumn('order_items', 'variant_label', {
      // ✅ سناب شوت لاسم الحجم وقت الطلب (نفس منطق unit_price) حتى لو
      // اتحذف الـ variant أو تغيّر اسمه لاحقًا
      type: Sequelize.STRING(50),
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('order_items', 'variant_label');
    await queryInterface.removeColumn('order_items', 'variant_id');
  },
};
