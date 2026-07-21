'use strict';

// ✅ مراجعة نظام الإشعارات الشاملة (2026-07-18): إضافة نوعين جديدين لتغطية
// أحداث كانت ما بتولّد أي إشعار إطلاقًا رغم إنها منطقيًا لازم - تقييم جديد
// (يبلّغ صاحب المتجر) ونقاط ولاء مكتسبة (يبلّغ الزبون). راجع notificationService.js
// و reviewController.js/loyaltyService.js لنقاط الاستدعاء الفعلية.
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn('notifications', 'type', {
      type: Sequelize.ENUM(
        'OrderStatus',
        'NewOrder',
        'SmartAssignmentOffer',
        'UserStatus',
        'AdminApproval',
        'NewReview',
        'LoyaltyEarned'
      ),
      allowNull: false,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.changeColumn('notifications', 'type', {
      type: Sequelize.ENUM('OrderStatus', 'NewOrder', 'SmartAssignmentOffer', 'UserStatus', 'AdminApproval'),
      allowNull: false,
    });
  },
};
