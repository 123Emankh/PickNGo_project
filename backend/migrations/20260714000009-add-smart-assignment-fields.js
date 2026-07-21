'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    // ✅ تفضيلات المتجر تُستخدم كمدخل لمحرك التعيين الذكي (Phase 3) - تُنسخ
    // على كل طلب وقت الإنشاء (نفس منطق delivery_fee) عشان يضل سجل الطلب
    // ثابت حتى لو المتجر غيّر تفضيلاته لاحقًا.
    await queryInterface.addColumn('restaurants', 'preferred_company_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'users', key: 'user_id' },
    });
    await queryInterface.addColumn('restaurants', 'required_vehicle_type', {
      type: Sequelize.STRING(30),
      allowNull: true,
    });

    await queryInterface.addColumn('orders', 'preferred_company_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'users', key: 'user_id' },
    });
    await queryInterface.addColumn('orders', 'required_vehicle_type', {
      type: Sequelize.STRING(30),
      allowNull: true,
    });

    // ✅ عرض حالي بانتظار رد سائق واحد بالذات - غير driver_id (يلي ما يتحدد
    // إلا بعد قبول فعلي). لو الوقت خلص بدون رد، الـ sweep بيصفّرهم ويجرب سائق تاني.
    await queryInterface.addColumn('orders', 'offered_driver_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'users', key: 'user_id' },
    });
    await queryInterface.addColumn('orders', 'offer_expires_at', {
      type: Sequelize.DATE,
      allowNull: true,
    });

    // ✅ وقت/نوع/سبب التعيين النهائي (لحظة ما driver_id يتحدد فعليًا - تلقائي
    // بقبول عرض، أو يدوي بانتقاء السائق من القائمة المفتوحة)
    await queryInterface.addColumn('orders', 'assigned_at', {
      type: Sequelize.DATE,
      allowNull: true,
    });
    await queryInterface.addColumn('orders', 'assignment_type', {
      type: Sequelize.ENUM('Auto', 'Manual'),
      allowNull: true,
    });
    await queryInterface.addColumn('orders', 'assignment_reason', {
      // ✅ تفصيل نقاط العوامل (مسافة/حمل/شركة/...) يلي أدت لاختيار السائق
      // النهائي - عشان يسهل تتبع القرار لاحقًا (دعم/أدمن)
      type: Sequelize.JSON,
      allowNull: true,
    });
    await queryInterface.addColumn('orders', 'offer_history', {
      // ✅ سجل كل محاولات العرض على هاد الطلب: [{driver_id, status, at, reason}, ...]
      // status: Offered/Accepted/Rejected/Expired/NoCandidate - نفس فلسفة status_history
      type: Sequelize.JSON,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('orders', 'offer_history');
    await queryInterface.removeColumn('orders', 'assignment_reason');
    await queryInterface.removeColumn('orders', 'assignment_type');
    await queryInterface.removeColumn('orders', 'assigned_at');
    await queryInterface.removeColumn('orders', 'offer_expires_at');
    await queryInterface.removeColumn('orders', 'offered_driver_id');
    await queryInterface.removeColumn('orders', 'required_vehicle_type');
    await queryInterface.removeColumn('orders', 'preferred_company_id');
    await queryInterface.removeColumn('restaurants', 'required_vehicle_type');
    await queryInterface.removeColumn('restaurants', 'preferred_company_id');
  },
};
