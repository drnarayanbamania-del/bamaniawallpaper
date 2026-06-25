// YBT Wallpaper — Category Routes
const express = require('express');
const { queryAll, queryGet, queryRun } = require('./db');
const { authMiddleware, adminMiddleware } = require('./auth');

const router = express.Router();

// ── List all categories ─────────────────────────────
router.get('/', (req, res) => {
  try {
    const categories = queryAll(`
      SELECT c.*, COUNT(w.id) as wallpaper_count
      FROM categories c
      LEFT JOIN wallpapers w ON c.id = w.category_id AND w.is_active = 1
      GROUP BY c.id
      ORDER BY c.name ASC
    `);

    res.json({ categories });
  } catch (err) {
    console.error('List categories error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Create category (admin) ─────────────────────────
router.post('/', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const { name } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Category name is required' });
    }

    const existing = queryGet('SELECT id FROM categories WHERE name = ?', [name.trim()]);
    if (existing) {
      return res.status(409).json({ error: 'Category already exists' });
    }

    const result = queryRun('INSERT INTO categories (name) VALUES (?)', [name.trim()]);

    res.status(201).json({
      message: 'Category created',
      category: { id: result.lastInsertRowid, name: name.trim() },
    });
  } catch (err) {
    console.error('Create category error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Delete category (admin) ─────────────────────────
router.delete('/:id', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const category = queryGet('SELECT id FROM categories WHERE id = ?', [parseInt(req.params.id)]);

    if (!category) {
      return res.status(404).json({ error: 'Category not found' });
    }

    const wallpaperCount = queryGet(
      'SELECT COUNT(*) as count FROM wallpapers WHERE category_id = ? AND is_active = 1',
      [parseInt(req.params.id)]
    );

    if (wallpaperCount && wallpaperCount.count > 0) {
      return res.status(400).json({
        error: `Cannot delete: ${wallpaperCount.count} wallpaper(s) use this category`,
      });
    }

    queryRun('DELETE FROM categories WHERE id = ?', [parseInt(req.params.id)]);
    res.json({ message: 'Category deleted' });
  } catch (err) {
    console.error('Delete category error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
