'use strict';

// ✅ لازمة لحساب رسم التوصيل الصحيح (داخل المدينة/مدينة تانية/مناطق محتلة)
// حسب مدينة/منطقة الزبون الفعلية وقت الطلب - مش تخمين من إحداثيات GPS.
// nullable لأنه الطلبات القديمة قبل هاد التعديل ما عندها هاد القيم، بس
// createOrder بيصير يطلبهم إلزاميًا لأي طلب جديد (راجع orderController.js).
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('orders', 'delivery_city', {
      type: Sequelize.STRING(50),
      allowNull: true,
    });
    await queryInterface.addColumn('orders', 'delivery_region', {
      type: Sequelize.STRING(50),
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('orders', 'delivery_city');
    await queryInterface.removeColumn('orders', 'delivery_region');
  },
};
