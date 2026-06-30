// YBT Wallpaper — Backend Configuration
// All config values live here. No .env file.
// Switch between dev and prod by changing baseUrl only.

const path = require('path');

module.exports = {
  // Server
  baseUrl: 'http://localhost:3000', // Change to your production domain (e.g., https://your-domain.com) in production
  port: 3000,

  // Database
  dbPath: path.join(__dirname, 'ybt_wallpaper.db'),

  // Storage
  storagePath: path.join(__dirname, 'storage'),
  maxFileSize: 10 * 1024 * 1024, // 10 MB

  // JWT
  jwtSecret: 'ybt-wallpaper-secret-key-change-in-production',
  jwtExpiry: '7d',

  // Admin (auto-created on first run)
  adminEmail: 'Admin123',
  adminPassword: '12345',

  // App
  appName: 'Bamania wall paper',
  supportEmail: 'support@yourdomain.com',
  version: '1.0.0',

  // Pagination
  paginationLimit: 20,
};
