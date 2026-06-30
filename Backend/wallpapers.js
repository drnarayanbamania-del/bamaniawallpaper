// YBT Wallpaper — Wallpaper Routes
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const config = require('./config');
const { queryAll, queryGet, queryRun } = require('./db');
const { authMiddleware, adminMiddleware } = require('./auth');

const router = express.Router();

// Ensure storage directory exists
if (!fs.existsSync(config.storagePath)) {
  fs.mkdirSync(config.storagePath, { recursive: true });
}

// Multer config
const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, config.storagePath),
    filename: (req, file, cb) => {
      const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
      cb(null, uniqueName);
    },
  }),
  limits: { fileSize: config.maxFileSize },
  fileFilter: (req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG, PNG, and WebP images are allowed'));
    }
  },
});

// ── List wallpapers (public, paginated) ─────────────
router.get('/', (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || config.paginationLimit;
    const offset = (page - 1) * limit;
    const categoryId = req.query.category_id;
    const search = req.query.search;

    let whereClause = 'WHERE w.is_active = 1';
    const params = [];

    if (categoryId) {
      whereClause += ' AND w.category_id = ?';
      params.push(parseInt(categoryId));
    }

    if (search) {
      whereClause += ' AND w.title LIKE ?';
      params.push(`%${search}%`);
    }

    const countRow = queryGet(
      `SELECT COUNT(*) as total FROM wallpapers w ${whereClause}`,
      params
    );

    const wallpapers = queryAll(`
      SELECT w.*, c.name as category_name
      FROM wallpapers w
      LEFT JOIN categories c ON w.category_id = c.id
      ${whereClause}
      ORDER BY w.created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);

    // Add full URL for each wallpaper
    const baseUrl = config.baseUrl;
    const data = wallpapers.map(w => ({
      ...w,
      file_url: `${baseUrl}/storage/${w.file_name}`,
    }));

    res.json({
      wallpapers: data,
      pagination: {
        page,
        limit,
        total: countRow ? countRow.total : 0,
        totalPages: Math.ceil((countRow ? countRow.total : 0) / limit),
      },
    });
  } catch (err) {
    console.error('List wallpapers error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Get single wallpaper ────────────────────────────
router.get('/:id', (req, res) => {
  try {
    const wallpaper = queryGet(`
      SELECT w.*, c.name as category_name
      FROM wallpapers w
      LEFT JOIN categories c ON w.category_id = c.id
      WHERE w.id = ? AND w.is_active = 1
    `, [parseInt(req.params.id)]);

    if (!wallpaper) {
      return res.status(404).json({ error: 'Wallpaper not found' });
    }

    wallpaper.file_url = `${config.baseUrl}/storage/${wallpaper.file_name}`;
    res.json({ wallpaper });
  } catch (err) {
    console.error('Get wallpaper error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Upload wallpaper (admin) ────────────────────────
router.post('/', authMiddleware, adminMiddleware, (req, res) => {
  upload.single('file')(req, res, (err) => {
    if (err) {
      if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ error: `File too large. Max size: ${config.maxFileSize / (1024 * 1024)} MB` });
      }
      return res.status(400).json({ error: err.message });
    }

    try {
      const { title, category_id, is_premium } = req.body;

      if (!title || !category_id || !req.file) {
        if (req.file) fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: 'Title, category, and image file are required' });
      }

      // Verify category exists
      const category = queryGet('SELECT id FROM categories WHERE id = ?', [parseInt(category_id)]);
      if (!category) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: 'Category not found' });
      }

      const result = queryRun(
        'INSERT INTO wallpapers (title, file_name, category_id, uploaded_by, is_premium) VALUES (?, ?, ?, ?, ?)',
        [title, req.file.filename, parseInt(category_id), req.user.id, parseInt(is_premium) || 0]
      );

      res.status(201).json({
        message: 'Wallpaper uploaded successfully',
        wallpaper: {
          id: result.lastInsertRowid,
          title,
          file_name: req.file.filename,
          file_url: `${config.baseUrl}/storage/${req.file.filename}`,
          category_id: parseInt(category_id),
        },
      });
    } catch (err) {
      console.error('Upload error:', err);
      if (req.file) fs.unlinkSync(req.file.path);
      res.status(500).json({ error: 'Server error' });
    }
  });
});

// ── Delete wallpaper (admin, soft delete) ───────────
router.delete('/:id', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const wallpaper = queryGet('SELECT * FROM wallpapers WHERE id = ?', [parseInt(req.params.id)]);

    if (!wallpaper) {
      return res.status(404).json({ error: 'Wallpaper not found' });
    }

    queryRun('UPDATE wallpapers SET is_active = 0 WHERE id = ?', [parseInt(req.params.id)]);
    res.json({ message: 'Wallpaper deleted' });
  } catch (err) {
    console.error('Delete wallpaper error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Download (increment count) ──────────────────────
router.post('/:id/download', authMiddleware, (req, res) => {
  try {
    const wallpaper = queryGet(
      'SELECT * FROM wallpapers WHERE id = ? AND is_active = 1',
      [parseInt(req.params.id)]
    );

    if (!wallpaper) {
      return res.status(404).json({ error: 'Wallpaper not found' });
    }

    // Get current user details to check if they are Pro
    const user = queryGet('SELECT is_pro FROM users WHERE id = ?', [req.user.id]);
    const isUserPro = user ? !!user.is_pro : false;

    // If wallpaper is premium and user is not Pro, block download!
    if (wallpaper.is_premium && !isUserPro) {
      return res.status(403).json({ error: 'Premium download requires PRO membership' });
    }

    // ── Enforce 24-Hour Rolling Download Limits for regular users ──
    if (!isUserPro) {
      const logs = queryAll(
        "SELECT id FROM download_logs WHERE user_id = ? AND downloaded_at >= datetime('now', '-24 hours')",
        [req.user.id]
      );
      if (logs.length >= 3) {
        return res.status(403).json({
          error: 'Daily download limit reached. Upgrade to PRO for unlimited downloads!'
        });
      }
    }

    // Record the download log
    queryRun('INSERT INTO download_logs (user_id, wallpaper_id) VALUES (?, ?)', [req.user.id, wallpaper.id]);

    queryRun('UPDATE wallpapers SET downloads = downloads + 1 WHERE id = ?', [parseInt(req.params.id)]);

    res.json({
      message: 'Download counted',
      file_url: `${config.baseUrl}/storage/${wallpaper.file_name}`,
      downloads: wallpaper.downloads + 1,
    });
  } catch (err) {
    console.error('Download error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
