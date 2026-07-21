'use strict';

// ✅ المساعد الذكي (Gemini): أول تخزين حقيقي لمحادثات الشات بوت بالمشروع.
// صف واحد لكل رسالة (من المستخدم أو من الموديل) - نفس فكرة notifications
// (راجع 20260714000012-create-notifications.js): سجل مسطّح بسيط بدون جدول
// "محادثات" منفصل، لأنه كل مستخدم عنده تاريخ محادثة واحد متواصل فقط (مافي
// مفهوم جلسات/قنوات متعددة بهاد النسخة). metadata بتخزن أي tool calls
// استخدمها الموديل لهاي الرسالة - لغايات تدقيق/تشخيص فقط، ما بتُعرض للمستخدم.
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('ai_chat_messages', {
      id: {
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
      role: {
        // 'user' = رسالة المستخدم، 'model' = رد المساعد
        type: Sequelize.ENUM('user', 'model'),
        allowNull: false,
      },
      content: { type: Sequelize.TEXT, allowNull: false },
      metadata: { type: Sequelize.JSON, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });

    // ✅ الاستعلام الأكثر تكرارًا: "آخر N رسالة لهاد المستخدم بالترتيب الزمني"
    await queryInterface.addIndex('ai_chat_messages', ['user_id', 'created_at']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('ai_chat_messages');
  },
};
