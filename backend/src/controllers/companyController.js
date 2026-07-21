// src/controllers/companyController.js
const { User, Order } = require('../models');
const { getIo } = require('../sockets');
const { getEffectiveStatus, broadcastDriverStatus } = require('../services/driverStatusService');

// ===========================
// 📌 GET /api/company/list  (شركات معتمدة فقط - عامة، تستخدم وقت تسجيل سائق جديد)
// ===========================
const listApprovedCompanies = async (req, res) => {
  try {
    const companies = await User.findAll({
      where: { role: 'Driver', business_type: 'Fleet / Company', status: 'Approved' },
      attributes: ['user_id', 'full_name', 'city', 'region']
    });

    res.status(200).json({
      success: true,
      companies: companies.map(c => ({
        id: c.user_id.toString(),
        name: c.full_name,
        city: c.city,
        region: c.region
      }))
    });
  } catch (error) {
    console.error('❌ List approved companies error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching delivery companies' });
  }
};

// ===========================
// 📌 Helper: يتحقق إنو المستخدم الحالي صاحب حساب شركة توصيل، ويرجعه
// ===========================
async function requireCompanyOwner(req, res) {
  const me = await User.findByPk(req.user.user_id);
  if (!me || me.business_type !== 'Fleet / Company') {
    res.status(403).json({ success: false, message: 'This account is not a delivery company' });
    return null;
  }
  return me;
}

function formatDriver(driver, extra = {}) {
  return {
    id: driver.user_id.toString(),
    full_name: driver.full_name,
    phone: driver.phone,
    email: driver.email,
    vehicle_type: driver.business_type,
    is_active: driver.is_active,
    status: driver.status,
    company_join_status: driver.company_join_status,
    ...extra
  };
}

// ===========================
// 📌 GET /api/company/roster  (سائقي شركتي المعتمدين - محمي، لصاحب حساب الشركة فقط)
// ===========================
const getMyRoster = async (req, res) => {
  try {
    const me = await requireCompanyOwner(req, res);
    if (!me) return;

    const drivers = await User.findAll({
      where: { company_id: me.user_id, company_join_status: 'Approved' },
      attributes: { exclude: ['password', 'reset_password_token', 'reset_password_expires'] },
      order: [['created_at', 'DESC']]
    });

    const roster = await Promise.all(
      drivers.map(async (driver) => {
        const [deliveredCount, earningsResult] = await Promise.all([
          Order.count({ where: { driver_id: driver.user_id, status: 'Delivered' } }),
          Order.sum('delivery_fee', { where: { driver_id: driver.user_id, status: 'Delivered' } })
        ]);

        return formatDriver(driver, {
          delivered_count: deliveredCount,
          earnings: parseFloat(earningsResult || 0),
          driver_status: getEffectiveStatus(driver)
        });
      })
    );

    res.status(200).json({ success: true, roster });
  } catch (error) {
    console.error('❌ Get company roster error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching company roster' });
  }
};

// ===========================
// 📌 GET /api/company/join-requests  (طلبات انضمام Pending لشركتي)
// ===========================
const getJoinRequests = async (req, res) => {
  try {
    const me = await requireCompanyOwner(req, res);
    if (!me) return;

    const drivers = await User.findAll({
      where: { company_id: me.user_id, company_join_status: 'Pending' },
      attributes: { exclude: ['password', 'reset_password_token', 'reset_password_expires'] },
      order: [['created_at', 'DESC']]
    });

    res.status(200).json({ success: true, requests: drivers.map((d) => formatDriver(d)) });
  } catch (error) {
    console.error('❌ Get join requests error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching join requests' });
  }
};

// ===========================
// 📌 Helper: يجيب سائق تابع لشركتي بالـ id، أو يرد 404/403 ويرجع null
// ===========================
async function findMyDriver(req, res, me) {
  const driver = await User.findByPk(req.params.driverId);
  if (!driver || driver.role !== 'Driver') {
    res.status(404).json({ success: false, message: 'Driver not found' });
    return null;
  }
  if (driver.company_id !== me.user_id) {
    res.status(403).json({ success: false, message: 'This driver is not part of your company' });
    return null;
  }
  return driver;
}

// ===========================
// 📌 POST /api/company/join-requests/:driverId/approve
// ===========================
const approveJoinRequest = async (req, res) => {
  try {
    const me = await requireCompanyOwner(req, res);
    if (!me) return;
    const driver = await findMyDriver(req, res, me);
    if (!driver) return;

    await driver.update({ company_join_status: 'Approved' });
    res.status(200).json({ success: true, message: 'Driver approved', driver: formatDriver(driver) });
  } catch (error) {
    console.error('❌ Approve join request error:', error);
    res.status(500).json({ success: false, message: 'Server error while approving join request' });
  }
};

// ===========================
// 📌 POST /api/company/join-requests/:driverId/reject  (بيحرر السائق يقدر يطلب شركة تانية)
// ===========================
const rejectJoinRequest = async (req, res) => {
  try {
    const me = await requireCompanyOwner(req, res);
    if (!me) return;
    const driver = await findMyDriver(req, res, me);
    if (!driver) return;

    await driver.update({ company_id: null, company_join_status: null });
    res.status(200).json({ success: true, message: 'Join request rejected' });
  } catch (error) {
    console.error('❌ Reject join request error:', error);
    res.status(500).json({ success: false, message: 'Server error while rejecting join request' });
  }
};

// ===========================
// 📌 DELETE /api/company/roster/:driverId  (إزالة سائق معتمد من الشركة)
// ===========================
const removeDriver = async (req, res) => {
  try {
    const me = await requireCompanyOwner(req, res);
    if (!me) return;
    const driver = await findMyDriver(req, res, me);
    if (!driver) return;

    await driver.update({ company_id: null, company_join_status: null });
    res.status(200).json({ success: true, message: 'Driver removed from company' });
  } catch (error) {
    console.error('❌ Remove driver error:', error);
    res.status(500).json({ success: false, message: 'Server error while removing driver' });
  }
};

// ===========================
// 📌 PATCH /api/company/roster/:driverId/active  (تفعيل/إيقاف سائق - body: { is_active })
// نفس عمود is_active العام يلي بيمنع تسجيل الدخول والوصول لأي API لو false
// (شوفي verifyUserToken.js) - يعني إيقاف السائق من هون بيوقفه فعليًا بالكامل.
// ===========================
const setDriverActive = async (req, res) => {
  try {
    const me = await requireCompanyOwner(req, res);
    if (!me) return;
    const driver = await findMyDriver(req, res, me);
    if (!driver) return;

    const { is_active } = req.body;
    if (typeof is_active !== 'boolean') {
      return res.status(400).json({ success: false, message: 'is_active (boolean) is required' });
    }

    await driver.update({ is_active });
    // ✅ إيقاف/تفعيل من الشركة بيأثر على الحالة الفعلية فورًا حتى لو driver_status
    // المخزّن ما تغيّر - منبثها عشان لوحة الأدمن ونفس لوحة الشركة يتحدثوا لحظيًا
    broadcastDriverStatus(driver, getIo());
    res.status(200).json({ success: true, message: 'Driver status updated', driver: formatDriver(driver, { driver_status: getEffectiveStatus(driver) }) });
  } catch (error) {
    console.error('❌ Set driver active error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating driver status' });
  }
};

module.exports = {
  listApprovedCompanies,
  getMyRoster,
  getJoinRequests,
  approveJoinRequest,
  rejectJoinRequest,
  removeDriver,
  setDriverActive
};
