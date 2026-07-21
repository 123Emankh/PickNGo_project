'use strict';

// ✅ نظام الإشعارات (Phase 4): ما كان في أي تخزين حقيقي للإشعارات بالمشروع
// قبل هيك - فقط أحداث Socket.io لحظية عابرة (order:status/order:offer/...)
// بتُفقد فور إغلاق التطبيق. هاد الجدول هو التخزين الحقيقي الأول: صف واحد
// لكل إشعار وصل لمستخدم، مع حالة قراءة تُحفظ وتُرجع بعد إعادة فتح التطبيق.
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('notifications', {
      notification_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      user_id: {
        // ✅ المستلم - أي دور (زبون/صاحب متجر/سائق/أدمن)
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'CASCADE',
      },
      title: { type: Sequelize.STRING(150), allowNull: false },
      body: { type: Sequelize.TEXT, allowNull: false },
      type: {
        // OrderStatus: تغيّر حالة طلب (للزبون) | NewOrder: طلب جديد (لصاحب المتجر)
        // SmartAssignmentOffer: عرض تعيين ذكي (للسائق، فردي أو مجمّع)
        // UserStatus: تغيّر حالة الحساب من الأدمن | AdminApproval: متجر/حساب جديد بانتظار الموافقة
        type: Sequelize.ENUM('OrderStatus', 'NewOrder', 'SmartAssignmentOffer', 'UserStatus', 'AdminApproval'),
        allowNull: false,
      },
      // ✅ لفتح الشاشة الصحيحة عند الضغط على الإشعار - 'Order'/'DeliveryGroup'/'Store' + المعرّف
      related_type: { type: Sequelize.STRING(30), allowNull: true },
      related_id: { type: Sequelize.INTEGER, allowNull: true },
      is_read: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });

    // ✅ الاستعلامان الأكثر تكرارًا: "قائمتي الأحدث فالأقدم" و"عدد غير المقروء"
    await queryInterface.addIndex('notifications', ['user_id', 'created_at']);
    await queryInterface.addIndex('notifications', ['user_id', 'is_read']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('notifications');
  },
};
