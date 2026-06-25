// YBT Wallpaper — Health Check Route
const express = require('express');
const config = require('./config');
const { getDb } = require('./db');

const router = express.Router();
const startTime = Date.now();

// ── Health check ────────────────────────────────────
router.get('/', (req, res) => {
  let dbStatus = 'ok';
  try {
    const db = getDb();
    db.exec('SELECT 1');
  } catch (err) {
    dbStatus = 'error';
  }

  const uptimeMs = Date.now() - startTime;
  const uptimeSeconds = Math.floor(uptimeMs / 1000);
  const hours = Math.floor(uptimeSeconds / 3600);
  const minutes = Math.floor((uptimeSeconds % 3600) / 60);
  const seconds = uptimeSeconds % 60;

  res.json({
    status: 'ok',
    app: config.appName,
    version: config.version,
    uptime: `${hours}h ${minutes}m ${seconds}s`,
    uptimeMs,
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
