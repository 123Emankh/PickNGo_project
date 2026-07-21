// src/controllers/driverController.js
const { getIo } = require('../sockets');
const { setDriverStatus, updateDriverLocation, getEffectiveStatus } = require('../services/driverStatusService');
const { computeDriverPerformance } = require('../services/analytics/driverAnalyticsService');

// ===========================
// 📌 PATCH /api/drivers/status  (تفعيل/إيقاف استقبال الطلبات - body: { status: 'Available'|'Offline' })
// ⚠️ Busy تتحدد تلقائيًا من النظام بس (قبول/إنهاء طلب) - السائق ما يقدر يحطها يدويًا
// ===========================
const setMyStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!['Available', 'Offline'].includes(status)) {
      return res.status(400).json({ success: false, message: "status must be 'Available' or 'Offline'" });
    }

    const driver = await setDriverStatus(req.user.user_id, status, getIo());
    if (!driver) {
      return res.status(404).json({ success: false, message: 'Driver not found' });
    }

    res.status(200).json({ success: true, status: getEffectiveStatus(driver) });
  } catch (error) {
    console.error('❌ Set driver status error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating status' });
  }
};

// ===========================
// 📌 POST /api/drivers/location  (ping دوري لموقع السائق الحالي - body: { lat, lng })
// ===========================
const pingLocation = async (req, res) => {
  try {
    const { lat, lng } = req.body;
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return res.status(400).json({ success: false, message: 'lat and lng (numbers) are required' });
    }

    const driver = await updateDriverLocation(req.user.user_id, lat, lng);
    if (!driver) {
      return res.status(404).json({ success: false, message: 'Driver not found' });
    }

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('❌ Ping driver location error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating location' });
  }
};

// ===========================
// 📌 GET /api/drivers/performance  (تحليلات أدائي - متوسط وقت التوصيل، نسب
// قبول/رفض عروض التعيين الذكي، عدد الطلبات المكتملة، معدّل الالتزام)
// ===========================
const getMyPerformance = async (req, res) => {
  try {
    const performance = await computeDriverPerformance(req.user.user_id);
    res.status(200).json({ success: true, performance });
  } catch (error) {
    console.error('❌ Get driver performance error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching performance analytics' });
  }
};

module.exports = { setMyStatus, pingLocation, getMyPerformance };
