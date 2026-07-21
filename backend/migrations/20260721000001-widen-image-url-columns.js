'use strict';

// ✅ image_url كان STRING(255) بجدولي restaurants وproducts - قصير عن روابط
// CDN حقيقية طويلة (مثلاً روابط Facebook الموقّعة اللي فيها query params
// كتير بتتجاوز 300-400 حرف)، وكان بيرمي "Data too long for column" وقت
// إدخال محلات حقيقية بروابط صور حقيقية. TEXT ما إله حد عملي لهيك حالات.
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn('restaurants', 'image_url', {
      type: Sequelize.TEXT,
      allowNull: true,
    });
    await queryInterface.changeColumn('products', 'image_url', {
      type: Sequelize.TEXT,
      allowNull: true,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.changeColumn('restaurants', 'image_url', {
      type: Sequelize.STRING(255),
      allowNull: true,
    });
    await queryInterface.changeColumn('products', 'image_url', {
      type: Sequelize.STRING(255),
      allowNull: true,
    });
  },
};
