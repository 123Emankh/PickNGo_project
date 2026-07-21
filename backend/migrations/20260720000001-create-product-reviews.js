'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('product_reviews', {
      product_review_id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      order_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'orders', key: 'order_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      product_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'products', key: 'product_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      customer_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'user_id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      rating: { type: Sequelize.INTEGER, allowNull: false },
      comment: { type: Sequelize.TEXT, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });

    // ✅ تقييم واحد لكل منتج ضمن نفس الطلب - يسمح بـ upsert نظيف عند تعديل
    // تقييم الطلب (نفس منطق unique(order_id) بجدول reviews، بس هون مركّب
    // مع product_id لأنو الطلب الواحد ممكن يحتوي أكتر من منتج)
    await queryInterface.addConstraint('product_reviews', {
      fields: ['order_id', 'product_id'],
      type: 'unique',
      name: 'product_reviews_order_id_product_id_unique',
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('product_reviews');
  },
};
