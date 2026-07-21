'use strict';

// ✅ استكمال ربط شاشة إعدادات/إنشاء المتجر: هاي الحقول كانت موجودة بالواجهة
// (فورم الإنشاء وفورم الإعدادات) بس بدون أعمدة حقيقية بالداتابيز - فبتُرسل
// وتُفقد بصمت. delivery_fee (الموجود أصلًا) بيضل هو الرسم الفعلي المستخدم
// وقت الطلب (checkout) = نسخة عن delivery_fee_inside_city دايمًا؛ الحقلين
// التانيين (outside/occupied) عرض/تسعير معلوماتي لصاحب المتجر والزبون حاليًا.
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('restaurants', 'delivery_fee_inside_city', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 10.0,
    });
    await queryInterface.addColumn('restaurants', 'delivery_fee_outside_city', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 20.0,
    });
    await queryInterface.addColumn('restaurants', 'delivery_fee_occupied_areas', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 70.0,
    });
    // ✅ وقت تحضير تقديري خاص بهاد المتجر (دقايق) - يستخدمه estimateDeliveryRange
    // بدل الثابت العام PREP_TIME_MIN لما يكون محدد
    await queryInterface.addColumn('restaurants', 'prep_time_minutes', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 10,
    });
    await queryInterface.addColumn('restaurants', 'supports_delivery', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    });
    await queryInterface.addColumn('restaurants', 'supports_pickup', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('restaurants', 'supports_pickup');
    await queryInterface.removeColumn('restaurants', 'supports_delivery');
    await queryInterface.removeColumn('restaurants', 'prep_time_minutes');
    await queryInterface.removeColumn('restaurants', 'delivery_fee_occupied_areas');
    await queryInterface.removeColumn('restaurants', 'delivery_fee_outside_city');
    await queryInterface.removeColumn('restaurants', 'delivery_fee_inside_city');
  },
};
