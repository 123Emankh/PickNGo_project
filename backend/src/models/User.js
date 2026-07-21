// src/models/User.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const User = sequelize.define('User', {
  user_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  full_name: {
    type: DataTypes.STRING(100),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Full name is required' },
      len: {
        args: [2, 100],
        msg: 'Full name must be between 2 and 100 characters'
      }
    }
  },
  email: {
    type: DataTypes.STRING(100),
    allowNull: false,
    unique: {
      msg: 'Email already registered'
    },
    validate: {
      isEmail: { msg: 'Invalid email format' },
      notEmpty: { msg: 'Email is required' }
    }
  },
  password: {
    type: DataTypes.STRING(255),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Password is required' },
      len: {
        args: [6, 255],
        msg: 'Password must be at least 6 characters'
      }
    }
  },
  phone: {
    type: DataTypes.STRING(20),
    allowNull: true,
    validate: {
      isValidPhone(value) {
        if (value && !/^[0-9+\-\s()]{10,15}$/.test(value)) {
          throw new Error('Invalid phone number format');
        }
      }
    }
  },
  profile_picture: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  role: {
    type: DataTypes.ENUM('Customer', 'Restaurant', 'Driver', 'Admin'),
    allowNull: false,
    defaultValue: 'Customer',
    validate: {
      isIn: {
        args: [['Customer', 'Restaurant', 'Driver', 'Admin']],
        msg: 'Invalid role. Allowed: Customer, Restaurant, Driver, Admin'
      }
    }
  },
  business_type: {
    // ✅ جديد: للـ Restaurant بيخزن (Restaurant/Pharmacy/Furniture/Other)
    // وللـ Driver بيخزن (Motorcycle/Cab/Company). فاضي للـ Customer.
    type: DataTypes.STRING(30),
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected', 'Suspended'),
    defaultValue: 'Pending',
    validate: {
      isIn: {
        args: [['Pending', 'Approved', 'Rejected', 'Suspended']],
        msg: 'Invalid status'
      }
    }
  },
  location_lat: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true,
    validate: {
      min: -90,
      max: 90
    }
  },
  location_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true,
    validate: {
      min: -180,
      max: 180
    }
  },
  location_address: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  city: {
    type: DataTypes.STRING(50),
    allowNull: true
  },
  region: {
    type: DataTypes.STRING(50),
    allowNull: true
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  is_verified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  last_login: {
    type: DataTypes.DATE,
    allowNull: true
  },
  reset_password_token: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  reset_password_expires: {
    type: DataTypes.DATE,
    allowNull: true
  },
  company_id: {
    // ✅ لو الشركة عندها business_type='Fleet / Company' معتمدة، هاد بيربط السائق فيها
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  company_join_status: {
    // ✅ حالة طلب انضمام السائق لشركته (لما company_id يكون معبّى) - منفصلة عن
    // status العام. Pending لحد ما الشركة توافق/ترفض عبر لوحتها.
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
    allowNull: true
  },
  last_active_at: {
    // ✅ آخر طلب مصادَق عليه - heartbeat بسيط لحالة السائق (Available/Offline)
    type: DataTypes.DATE,
    allowNull: true
  },
  driver_status: {
    // ✅ حالة السائق الحقيقية (مخزّنة) - Offline افتراضيًا، بتتغير عبر
    // driverStatusService فقط (مش مباشرة) عشان تبقى مبثوثة لحظيًا بالسوكيت
    type: DataTypes.ENUM('Offline', 'Available', 'Busy'),
    allowNull: false,
    defaultValue: 'Offline'
  },
  current_lat: {
    // ✅ آخر موقع حي (مش عنوان التسجيل location_lat) - من ping دوري لتطبيق السائق
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  current_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  location_updated_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  loyalty_points: {
    // ✅ رصيد مخزّن/مكافئ (cached) - مصدر الحقيقة الفعلي جدول
    // loyalty_transactions (راجع loyaltyService.js)
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
  }
}, {
  tableName: 'users',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
  
  indexes: [
    {
      name: 'idx_users_email',
      fields: ['email']
    },
    {
      name: 'idx_users_role',
      fields: ['role']
    },
    {
      name: 'idx_users_status',
      fields: ['status']
    }
  ]
});

module.exports = User;