// src/services/driverStatusService.js
//
// المصدر الوحيد للحقيقة (single source of truth) لحالة السائق بكل النظام:
// لوحة الشركة، لوحة الأدمن، ولاحقًا نظام التوزيع الذكي. أي جزء بالنظام
// بده يقرأ أو يغيّر حالة سائق لازم يمر من هون - ما منكرر منطق الحالة
// بأي كونترولر تاني.
const { Op } = require('sequelize');
const { User } = require('../models');

// لو ما وصل ping موقع من السائق خلال هاد الوقت وهو Available/Busy، منعتبره
// انقطع اتصاله ومنرجّعه Offline تلقائيًا (سواء وقت القراءة أو بالـ sweep الدوري)
const ONLINE_STALE_MINUTES = 3;
const SWEEP_INTERVAL_MS = 60 * 1000;

function isStale(driver) {
  if (!driver.location_updated_at) return true;
  const staleSince = Date.now() - ONLINE_STALE_MINUTES * 60 * 1000;
  return new Date(driver.location_updated_at).getTime() < staleSince;
}

/**
 * الحالة "الفعلية" لسائق - بتاخد بعين الاعتبار انقطاع الاتصال حتى لو العمود
 * المخزّن لسا ما انحدّث (شبكة أمان بين نبضات الـ sweep الدوري).
 */
function getEffectiveStatus(driver) {
  if (!driver || driver.role !== 'Driver') return 'Offline';
  if (driver.driver_status === 'Offline') return 'Offline';
  if (!driver.is_active || driver.status !== 'Approved') return 'Offline';
  if (isStale(driver)) return 'Offline';
  return driver.driver_status;
}

function roomNames(driver) {
  const rooms = ['driver-status:admin', `driver-status:self:${driver.user_id}`];
  if (driver.company_id) rooms.push(`driver-status:company:${driver.company_id}`);
  return rooms;
}

function broadcastDriverStatus(driver, io) {
  if (!io) return;
  const payload = {
    driver_id: driver.user_id,
    status: getEffectiveStatus(driver),
    updated_at: new Date()
  };
  for (const room of roomNames(driver)) {
    io.to(room).emit('driver:status', payload);
  }
}

/**
 * يغيّر حالة سائق ويبثّها لحظيًا. هاي الدالة الوحيدة يلي المفروض تكتب على
 * عمود driver_status - أي مكان تاني بده يغيّر الحالة لازم ينادي عليها.
 */
async function setDriverStatus(driverId, status, io) {
  if (!['Offline', 'Available', 'Busy'].includes(status)) return null;

  const driver = await User.findByPk(driverId);
  if (!driver || driver.role !== 'Driver') return null;
  if (driver.driver_status === status) return driver; // ما في تغيير فعلي - منتجنب ضجيج سوكيت

  await driver.update({ driver_status: status });
  broadcastDriverStatus(driver, io);
  return driver;
}

/**
 * ping دوري من تطبيق السائق (موقعه الحالي) - بيحدّث الموقع بس، ما بيغيّر
 * الحالة المخزّنة (احترامًا لو السائق حط Offline بنفسه عن قصد).
 */
async function updateDriverLocation(driverId, lat, lng) {
  const driver = await User.findByPk(driverId);
  if (!driver || driver.role !== 'Driver') return null;

  await driver.update({
    current_lat: lat,
    current_lng: lng,
    location_updated_at: new Date()
  });
  return driver;
}

/**
 * فحص دوري: أي سائق Available/Busy بس منقطع (ما بعت موقع من زمان) بيترجّع
 * Offline تلقائيًا + بث الحدث - عشان لوحات الشركة/الأدمن تتحدث لحظيًا حتى
 * لو محدا فتح الصفحة بالضبط لحظة الانقطاع.
 */
async function sweepStaleDrivers(io) {
  try {
    const staleSince = new Date(Date.now() - ONLINE_STALE_MINUTES * 60 * 1000);
    const candidates = await User.findAll({
      where: {
        role: 'Driver',
        driver_status: { [Op.in]: ['Available', 'Busy'] },
        [Op.or]: [{ location_updated_at: null }, { location_updated_at: { [Op.lt]: staleSince } }]
      }
    });

    for (const driver of candidates) {
      await driver.update({ driver_status: 'Offline' });
      broadcastDriverStatus(driver, io);
    }
  } catch (error) {
    console.error('❌ sweepStaleDrivers error:', error);
  }
}

let sweepTimer = null;
function startStalenessSweep(io) {
  if (sweepTimer) return; // منمنع نبدأ أكتر من interval واحد (hot restart إلخ)
  sweepTimer = setInterval(() => sweepStaleDrivers(io), SWEEP_INTERVAL_MS);
}

module.exports = {
  getEffectiveStatus,
  setDriverStatus,
  updateDriverLocation,
  broadcastDriverStatus,
  startStalenessSweep,
  ONLINE_STALE_MINUTES
};
