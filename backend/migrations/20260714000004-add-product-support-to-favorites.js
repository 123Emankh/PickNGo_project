'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn('favorites', 'restaurant_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'restaurants', key: 'restaurant_id' },
    });

    await queryInterface.addColumn('favorites', 'product_id', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: { model: 'products', key: 'product_id' },
    });

    await queryInterface.addIndex('favorites', ['user_id', 'product_id'], {
      unique: true,
      name: 'favorites_user_product_unique',
    });
  },

  async down(queryInterface) {
    await queryInterface.removeIndex('favorites', 'favorites_user_product_unique');
    await queryInterface.removeColumn('favorites', 'product_id');
    await queryInterface.changeColumn('favorites', 'restaurant_id', {
      type: require('sequelize').INTEGER,
      allowNull: false,
    });
  },
};
