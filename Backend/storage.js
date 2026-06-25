// YBT Wallpaper — Storage Management Routes (Admin only)
const express = require('express');
const fs = require('fs');
const path = require('path');
const config = require('./config');
const { queryAll } = require('./db');
const { authMiddleware, adminMiddleware } = require('./auth');

const router = express.Router();

// ── Storage stats ───────────────────────────────────
router.get('/stats', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const storagePath = config.storagePath;

    if (!fs.existsSync(storagePath)) {
      return res.json({ totalFiles: 0, usedMB: 0 });
    }

    const files = fs.readdirSync(storagePath);
    let totalSize = 0;

    files.forEach(file => {
      const filePath = path.join(storagePath, file);
      const stat = fs.statSync(filePath);
      if (stat.isFile()) {
        totalSize += stat.size;
      }
    });

    res.json({
      totalFiles: files.length,
      usedMB: parseFloat((totalSize / (1024 * 1024)).toFixed(2)),
      usedBytes: totalSize,
    });
  } catch (err) {
    console.error('Storage stats error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Cleanup orphan files ────────────────────────────
router.delete('/cleanup', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const storagePath = config.storagePath;

    if (!fs.existsSync(storagePath)) {
      return res.json({ message: 'No files to clean up', deleted: 0 });
    }

    const dbFiles = queryAll('SELECT file_name FROM wallpapers');
    const dbFileNames = new Set(dbFiles.map(f => f.file_name));

    const diskFiles = fs.readdirSync(storagePath);
    let deletedCount = 0;

    diskFiles.forEach(file => {
      if (!dbFileNames.has(file)) {
        const filePath = path.join(storagePath, file);
        const stat = fs.statSync(filePath);
        if (stat.isFile()) {
          fs.unlinkSync(filePath);
          deletedCount++;
        }
      }
    });

    res.json({
      message: `Cleanup complete. ${deletedCount} orphan file(s) deleted.`,
      deleted: deletedCount,
    });
  } catch (err) {
    console.error('Storage cleanup error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
