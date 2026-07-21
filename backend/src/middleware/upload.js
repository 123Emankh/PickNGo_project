// src/middleware/upload.js
const multer = require('multer');
const path = require('path');

const AVATAR_DIR = path.join(__dirname, '../uploads/profiles');
const ALLOWED_AVATAR_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB

const avatarStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, AVATAR_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `avatar_${req.user.user_id}_${Date.now()}${ext}`);
  }
});

const avatarUpload = multer({
  storage: avatarStorage,
  limits: { fileSize: MAX_AVATAR_SIZE },
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_AVATAR_TYPES.includes(file.mimetype)) {
      const err = new Error('Only JPEG, PNG or WEBP images are allowed');
      err.status = 400;
      return cb(err);
    }
    cb(null, true);
  }
});

module.exports = { avatarUpload };
