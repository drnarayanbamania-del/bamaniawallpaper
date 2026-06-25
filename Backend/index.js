// YBT Wallpaper — Server Entry Point
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const config = require('./config');
const { initDb } = require('./db');

const app = express();

// ── Middleware ───────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Ensure storage directory exists ─────────────────
if (!fs.existsSync(config.storagePath)) {
  fs.mkdirSync(config.storagePath, { recursive: true });
}

// ── Static files ────────────────────────────────────
app.use('/storage', express.static(config.storagePath));

// ── Admin panel ─────────────────────────────────────
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// ── Routes ──────────────────────────────────────────
const { router: authRouter } = require('./auth');
const wallpapersRouter = require('./wallpapers');
const categoriesRouter = require('./categories');
const usersRouter = require('./users');
const healthRouter = require('./health');
const storageRouter = require('./storage');

app.use('/api', authRouter);
app.use('/api/wallpapers', wallpapersRouter);
app.use('/api/categories', categoriesRouter);
app.use('/api/users', usersRouter);
app.use('/api/health', healthRouter);
app.use('/api/storage', storageRouter);

// ── Initialize DB (async with sql.js) then start ────
async function start() {
  await initDb();

  const port = process.env.PORT || config.port;
  app.listen(port, () => {
    console.log(`\n  ${config.appName} Backend`);
    console.log(`  ─────────────────────────────`);
    console.log(`  Server:  ${config.baseUrl}`);
    console.log(`  Admin:   ${config.baseUrl}/admin`);
    console.log(`  Health:  ${config.baseUrl}/api/health`);
    console.log(`  ─────────────────────────────\n`);
  });
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
