// src/services/emailService.js
const nodemailer = require('nodemailer');
require('dotenv').config();

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT) || 587,
  secure: process.env.SMTP_PORT === '465',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  pool: true,
  maxConnections: 5,
  maxMessages: 100,
  rateDelta: 1000,
  rateLimit: 5
});

transporter.verify((error, success) => {
  if (error) {
    console.error('❌ Email transporter error:', error);
  } else {
    console.log('✅ Email service is ready');
  }
});

/**
 * Send email
 * @param {string} to - Recipient email
 * @param {string} subject - Email subject
 * @param {string} text - Plain text content
 * @param {string} html - HTML content (optional)
 * @returns {Promise}
 */
const sendEmail = async (to, subject, text, html = null) => {
  try {
    const mailOptions = {
      from: process.env.SMTP_FROM || `"Delivery App" <${process.env.SMTP_USER}>`,
      to,
      subject,
      text,
      html: html || text.replace(/\n/g, '<br>')
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`✅ Email sent to ${to}: ${info.messageId}`);
    return info;
  } catch (error) {
    console.error('❌ Email sending error:', error);
    throw new Error(`Failed to send email: ${error.message}`);
  }
};

/**
 * Send OTP email
 * @param {string} to - Recipient email
 * @param {string} otp - OTP code
 * @param {string} type - OTP type (Verification, ResetPassword, Login)
 * @param {number} expiryMinutes - Expiry time in minutes
 */
const sendOTPEmail = async (to, otp, type = 'Verification', expiryMinutes = 15) => {
  const subject = type === 'Verification' 
    ? 'Verify Your Email - Delivery App' 
    : type === 'ResetPassword' 
    ? 'Reset Your Password - Delivery App'
    : 'Login Verification - Delivery App';

  const text = `
    Hello,

    Your ${type.toLowerCase()} code is: ${otp}

    This code will expire in ${expiryMinutes} minutes.

    If you didn't request this code, please ignore this email.

    Thanks,
    Delivery App Team
  `;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #333;">${subject}</h2>
      <p style="color: #555; font-size: 16px; line-height: 1.6;">
        Your ${type.toLowerCase()} code is:
      </p>
      <div style="background: #f4f4f4; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
        <h1 style="font-size: 36px; letter-spacing: 10px; color: #2c3e50; margin: 0;">
          ${otp}
        </h1>
      </div>
      <p style="color: #555; font-size: 14px; line-height: 1.6;">
        This code will expire in <strong>${expiryMinutes} minutes</strong>.
      </p>
      <p style="color: #888; font-size: 12px; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;">
        If you didn't request this code, please ignore this email.
      </p>
      <p style="color: #888; font-size: 12px;">
        &copy; ${new Date().getFullYear()} Delivery App. All rights reserved.
      </p>
    </div>
  `;

  return await sendEmail(to, subject, text, html);
};

/**
 * Send welcome email
 * @param {string} to - Recipient email
 * @param {string} name - User's full name
 * @param {string} role - User's role
 */
const sendWelcomeEmail = async (to, name, role) => {
  const subject = 'Welcome to Delivery App! 🚀';

  const text = `
    Hello ${name},

    Welcome to Delivery App! Your account has been successfully created.

    Account Details:
    - Name: ${name}
    - Role: ${role}

    You can now log in and start using our services.

    If you have any questions, feel free to contact our support.

    Best regards,
    Delivery App Team
  `;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #333;">Welcome to Delivery App! 🚀</h2>
      <p style="color: #555; font-size: 16px; line-height: 1.6;">
        Hello <strong>${name}</strong>,
      </p>
      <p style="color: #555; font-size: 16px; line-height: 1.6;">
        Welcome to Delivery App! Your account has been successfully created.
      </p>
      <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0;">
        <p style="margin: 5px 0;"><strong>Account Details:</strong></p>
        <p style="margin: 5px 0;">📧 Email: ${to}</p>
        <p style="margin: 5px 0;">👤 Role: ${role}</p>
      </div>
      <p style="color: #555; font-size: 16px; line-height: 1.6;">
        You can now log in and start using our services.
      </p>
      <p style="color: #555; font-size: 16px; line-height: 1.6;">
        If you have any questions, feel free to contact our support.
      </p>
      <p style="color: #555; font-size: 16px; line-height: 1.6;">
        Best regards,<br>
        <strong>Delivery App Team</strong>
      </p>
    </div>
  `;

  return await sendEmail(to, subject, text, html);
};

module.exports = {
  sendEmail,
  sendOTPEmail,
  sendWelcomeEmail
};