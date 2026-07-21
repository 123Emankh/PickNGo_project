'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    // ✅ إعدادات النظام (قابلة للتعديل من لوحة الأدمن عبر GET/PUT /api/admin/settings
    // الموجودة أصلًا - نفس نمط إعدادات Grouped Delivery بالضبط)
    await queryInterface.addColumn('system_settings', 'loyalty_enabled', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    });
    await queryInterface.addColumn('system_settings', 'points_earn_rate', {
      // نقاط لكل وحدة عملة من قيمة الطلب النهائية وقت التسليم
      type: Sequelize.DECIMAL(6, 2),
      allowNull: false,
      defaultValue: 1,
    });
    await queryInterface.addColumn('system_settings', 'points_redeem_rate', {
      // قيمة النقطة الوحدة بالعملة وقت الاستبدال بالـ checkout
      type: Sequelize.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0.01,
    });

    // ✅ رصيد النقاط الحالي - مخزّن/مكافئ (cached) بالمستخدم لقراءة سريعة
    // (يُستخدم بكل عملية تسجيل دخول/شاشة رئيسية محتملة)، مصدر الحقيقة الفعلي
    // هو جدول loyalty_transactions تحت (نفس فلسفة Restaurant.rating المحسوبة
        // من جدول reviews - مجموع loyalty_transactions.points لنفس المستخدم
    // لازم يساوي هاد الرقم دايمًا).
    await queryInterface.addColumn('users', 'loyalty_points', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0,
    });

    // ✅ لقطة على الطلب نفسه: كم نقطة كُسبت/استُبدلت بالضبط وقتها - ضرورية
    // لعكس (reverse) العملية بدقة لو الطلب انلغى/انفتح من جديد لاحقًا، بدون
    // إعادة حساب قد ياخد رقم مختلف لو تغيّرت إعدادات النظام بين الوقتين.
    await queryInterface.addColumn('orders', 'points_earned', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0,
    });
    await queryInterface.addColumn('orders', 'points_earned_at', {
      type: Sequelize.DATE,
      allowNull: true,
    });
    await queryInterface.addColumn('orders', 'points_redeemed', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0,
    });
    await queryInterface.addColumn('orders', 'points_redeemed_value', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0,
    });
    await queryInterface.addColumn('orders', 'points_redemption_refunded', {
      // ✅ منع استرجاع مزدوج لنفس النقاط المستبدلة لو الطلب انلغى أكتر من مرة
      // بأي شكل (idempotency guard)
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    });

    // ✅ دفتر أستاذ (ledger) كامل - سجل تدقيق لا يُعدَّل، مصدر الحقيقة الوحيد
    // لرصيد كل مستخدم. كل صف = حركة واحدة، balance_after لقطة على الرصيد
    // لحظتها (يسهّل تدقيق/دعم بدون إعادة حساب كامل السجل من الصفر).
    await queryInterface.createTable('loyalty_transactions', {
      transaction_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
      },
      order_id: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'orders', key: 'order_id' },
      },
      type: {
        // Earned: طلب Delivered | Redeemed: استبدال بالـ checkout |
        // Reversed: سحب نقاط مكسوبة (الطلب رجع عن Delivered - إلغاء/إعادة فتح) |
        // Refunded: إرجاع نقاط مستبدلة (الطلب اللي استُبدلت عليه انلغى)
        type: Sequelize.ENUM('Earned', 'Redeemed', 'Reversed', 'Refunded'),
        allowNull: false,
      },
      points: {
        // موجب لـ Earned/Refunded، سالب لـ Redeemed/Reversed
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      balance_after: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      description: {
        type: Sequelize.STRING(255),
        allowNull: true,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.addIndex('loyalty_transactions', ['user_id']);
    await queryInterface.addIndex('loyalty_transactions', ['order_id']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('loyalty_transactions');
    await queryInterface.removeColumn('orders', 'points_redemption_refunded');
    await queryInterface.removeColumn('orders', 'points_redeemed_value');
    await queryInterface.removeColumn('orders', 'points_redeemed');
    await queryInterface.removeColumn('orders', 'points_earned_at');
    await queryInterface.removeColumn('orders', 'points_earned');
    await queryInterface.removeColumn('users', 'loyalty_points');
    await queryInterface.removeColumn('system_settings', 'points_redeem_rate');
    await queryInterface.removeColumn('system_settings', 'points_earn_rate');
    await queryInterface.removeColumn('system_settings', 'loyalty_enabled');
  },
};
