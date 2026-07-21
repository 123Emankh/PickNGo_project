'use strict';

// ✅ Grouped Delivery (Smart Order Clustering): طلبات لنفس الزبون من متاجر
// قريبة من بعض (وبنفس عنوان توصيل قريب، وبفارق وقت قصير) تُجمع برحلة توصيل
// وحدة بدل ما كل طلب ياخد سائق لحاله. الجدولين هون + عمود واحد بس على orders
// - باقي بنية orders ما إلها علاقة.
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('delivery_groups', {
      group_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      customer_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
      },
      status: {
        // Forming: لسا ممكن ينضم إلها طلبات/بانتظار تعيين سائق. Assigned: سائق
        // محدد. Completed: كل الطلبات وصلت حالة نهائية. Cancelled: احتياطي.
        type: Sequelize.ENUM('Forming', 'Assigned', 'Completed', 'Cancelled'),
        allowNull: false,
        defaultValue: 'Forming',
      },
      driver_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'users', key: 'user_id' },
      },
      // ✅ نفس شكل حقول عرض Phase 3 بالضبط (orders.offered_driver_id/...) -
      // عشان groupAssignmentService يعيد استخدام نفس منطق دورة حياة العرض
      offered_driver_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'users', key: 'user_id' },
      },
      offer_expires_at: { type: Sequelize.DATE, allowNull: true },
      assigned_at: { type: Sequelize.DATE, allowNull: true },
      assignment_type: {
        type: Sequelize.ENUM('Auto', 'Manual'),
        allowNull: true,
      },
      assignment_reason: { type: Sequelize.JSON, allowNull: true },
      offer_history: { type: Sequelize.JSON, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });

    await queryInterface.createTable('delivery_group_items', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      group_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'delivery_groups', key: 'group_id' },
        onDelete: 'CASCADE',
      },
      order_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        unique: true,
        references: { model: 'orders', key: 'order_id' },
        onDelete: 'CASCADE',
      },
      // ✅ ترتيب زيارة المتجر بالرحلة (1=أول توقف). نقطة التوسّع لـ Route
      // Optimization لاحقًا - بيعاد حسابها هون بدون أي تعديل بالسكيما.
      pickup_sequence: { type: Sequelize.INTEGER, allowNull: false },
      created_at: { type: Sequelize.DATE, allowNull: false },
    });

    // ✅ العمود الوحيد المضاف على orders - كل شي تاني بجدول الطلب زي ما هو
    await queryInterface.addColumn('orders', 'delivery_group_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'delivery_groups', key: 'group_id' },
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('orders', 'delivery_group_id');
    await queryInterface.dropTable('delivery_group_items');
    await queryInterface.dropTable('delivery_groups');
  },
};
