'use strict';

// ⚠️ اكتشاف أثناء الاختبار: كان في جدول `notifications` قديم فاضي (0 صفوف)
// بالداتابيز من قبل هاد الـ phase بالكامل - بأعمدة مختلفة تمامًا (order_id،
// message، language، data) ومش مرتبط بأي Model/Controller/Route بالكود
// الحالي (تأكدت بمراجعة شاملة قبل البدء). الـ migration السابقة
// (20260714000012) عملت CREATE TABLE IF NOT EXISTS ضمنيًا فما بدّلت شكله -
// بس الـ addIndex فيها نجحت لأنها استهدفت أعمدة (user_id/created_at/is_read)
// موجودة أصلًا بالجدول القديم. بما إنه فاضي بالكامل وما إله أي كود يعتمد
// عليه، هاي migration تحذفه وتنشئه من جديد بالشكل الصحيح المطلوب لنظام
// الإشعارات الجديد (title/body/type/related_type/related_id).
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.dropTable('notifications');

    await queryInterface.createTable('notifications', {
      notification_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'CASCADE',
      },
      title: { type: Sequelize.STRING(150), allowNull: false },
      body: { type: Sequelize.TEXT, allowNull: false },
      type: {
        type: Sequelize.ENUM('OrderStatus', 'NewOrder', 'SmartAssignmentOffer', 'UserStatus', 'AdminApproval'),
        allowNull: false,
      },
      related_type: { type: Sequelize.STRING(30), allowNull: true },
      related_id: { type: Sequelize.INTEGER, allowNull: true },
      is_read: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });

    await queryInterface.addIndex('notifications', ['user_id', 'created_at']);
    await queryInterface.addIndex('notifications', ['user_id', 'is_read']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('notifications');
  },
};
